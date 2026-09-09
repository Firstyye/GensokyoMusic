import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  get,
  onDisconnect,
  ref,
  remove,
  serverTimestamp,
  set,
} from "firebase/database";
import {afterAll, beforeAll, beforeEach, describe, expect, it} from "vitest";

const projectId = "demo-gensokyo-music-rules";

function participant(name: string, isHost: boolean) {
  return {
    name,
    photoUrl: "",
    isHost,
    joinedAt: serverTimestamp(),
  };
}

function seededParticipant(name: string, joinedAt: number, isHost: boolean) {
  return {name, photoUrl: "", joinedAt, isHost};
}

function seededSong() {
  return {
    title: "Moon",
    artist: "ZUN",
    thumbnailUrl: "cover",
    youtubeVideoId: "video",
  };
}

function party(participants: Record<string, unknown>) {
  return {
    hostUid: "host",
    hostName: "Host",
    status: "active",
    createdAt: 1,
    state: {
      isPlaying: true,
      positionSeconds: 10,
      updatedAt: 1,
      song: seededSong(),
    },
    participants,
    queue: {seed: seededSong()},
    chat: {
      seed: {
        uid: "host",
        name: "Host",
        photoUrl: "",
        message: "Welcome",
        timestamp: 1,
      },
    },
  };
}

function transferredParty(overrides: Record<string, unknown> = {}) {
  return {
    hostUid: "listener",
    hostName: "Listener",
    status: "active",
    createdAt: 1,
    state: {
      isPlaying: true,
      positionSeconds: 10,
      updatedAt: 1,
      song: seededSong(),
    },
    participants: {
      listener: seededParticipant("Listener", 2, true),
      later: seededParticipant("Later", 3, false),
    },
    queue: {seed: seededSong()},
    chat: {
      seed: {
        uid: "host",
        name: "Host",
        photoUrl: "",
        message: "Welcome",
        timestamp: 1,
      },
    },
    ...overrides,
  };
}

describe("Realtime Database security rules", () => {
  let testEnv: RulesTestEnvironment;

  beforeAll(async () => {
    testEnv = await initializeTestEnvironment({
      projectId,
      database: {
        rules: readFileSync(resolve(__dirname, "../../database.rules.json"), "utf8"),
      },
    });
  });

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await remove(ref(context.database(), "parties/future"));
      await set(ref(context.database(), "parties/p"), party({
        host: seededParticipant("Host", 1, true),
        listener: seededParticipant("Listener", 2, false),
        later: seededParticipant("Later", 3, false),
      }));
      await set(ref(context.database(), "private_chats/host_listener"), {
        messages: {seed: {text: "hello"}},
      });
      await set(ref(context.database(), "status/listener"), {
        isOnline: true,
        lastSeen: 1,
      });
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  it("uses a database namespace isolated from function integration tests", () => {
    const database = testEnv.authenticatedContext("namespace-check").database();
    const namespace = (database as unknown as {
      _delegate: {_repoInternal: {repoInfo_: {namespace: string}}};
    })._delegate._repoInternal.repoInfo_.namespace;

    expect(namespace).toBe("demo-gensokyo-music-rules");
  });

  it("rejects unauthenticated party-list reads", async () => {
    const unauthenticatedDb = testEnv.unauthenticatedContext().database();

    await assertFails(get(ref(unauthenticatedDb, "parties")));
  });

  it("allows authenticated party-list reads", async () => {
    const hostDb = testEnv.authenticatedContext("host").database();

    await assertSucceeds(get(ref(hostDb, "parties")));
  });

  it("allows a future host to register a no-op disconnect removal", async () => {
    const hostDb = testEnv.authenticatedContext("future-host").database();
    const futureHostRef = ref(
      hostDb,
      "parties/future/participants/future-host",
    );

    await assertSucceeds(onDisconnect(futureHostRef).remove());
  });

  it("allows the current host to arm root deletion on disconnect", async () => {
    const hostDb = testEnv.authenticatedContext("host").database();

    await assertSucceeds(onDisconnect(ref(hostDb, "parties/p")).remove());
  });

  it("rejects root disconnect deletion armed by a listener", async () => {
    const listenerDb = testEnv.authenticatedContext("listener").database();

    await assertFails(onDisconnect(ref(listenerDb, "parties/p")).remove());
  });

  it("allows a host to create a valid one-host active party", async () => {
    const hostDb = testEnv.authenticatedContext("future-host").database();

    await assertSucceeds(set(ref(hostDb, "parties/future"), {
      hostUid: "future-host",
      hostName: "Future Host",
      status: "active",
      createdAt: serverTimestamp(),
      state: {isPlaying: false, positionSeconds: 0},
      participants: {
        "future-host": participant("Future Host", true),
      },
    }));
  });

  it("rejects party creation containing an extra participant", async () => {
    const hostDb = testEnv.authenticatedContext("future-host").database();

    await assertFails(set(ref(hostDb, "parties/future"), {
      hostUid: "future-host",
      hostName: "Future Host",
      status: "active",
      createdAt: serverTimestamp(),
      state: {isPlaying: false, positionSeconds: 0},
      participants: {
        "future-host": participant("Future Host", true),
        outsider: participant("Outsider", false),
      },
    }));
  });

  it("rejects listener playback-state writes", async () => {
    const listenerDb = testEnv.authenticatedContext("listener").database();

    await assertFails(set(
      ref(listenerDb, "parties/p/state/isPlaying"),
      false,
    ));
  });

  it("rejects listener queue writes", async () => {
    const listenerDb = testEnv.authenticatedContext("listener").database();
    const song = {title: "Bad Apple!!", artist: "Alstroemeria Records"};

    await assertFails(set(ref(listenerDb, "parties/p/queue/new"), song));
  });

  it("allows host playback-state writes", async () => {
    const hostDb = testEnv.authenticatedContext("host").database();

    await assertSucceeds(set(
      ref(hostDb, "parties/p/state/isPlaying"),
      false,
    ));
  });

  it("allows a listener to create their own membership with server time", async () => {
    const listenerDb = testEnv.authenticatedContext("new-listener").database();
    const memberWithServerTimestamp = participant("New Listener", false);

    await assertSucceeds(set(
      ref(listenerDb, "parties/p/participants/new-listener"),
      memberWithServerTimestamp,
    ));
  });

  it("allows a listener to remove their own membership", async () => {
    const listenerDb = testEnv.authenticatedContext("listener").database();

    await assertSucceeds(remove(
      ref(listenerDb, "parties/p/participants/listener"),
    ));
  });

  it("rejects membership creation under a missing party", async () => {
    const listenerDb = testEnv.authenticatedContext("listener").database();
    const memberData = participant("Listener", false);

    await assertFails(set(
      ref(listenerDb, "parties/missing/participants/listener"),
      memberData,
    ));
  });

  it("rejects a direct numeric timestamp when creating membership", async () => {
    const listenerDb = testEnv.authenticatedContext("numeric-listener").database();

    await assertFails(set(
      ref(listenerDb, "parties/p/participants/numeric-listener"),
      {
        name: "Numeric Listener",
        photoUrl: "",
        isHost: false,
        joinedAt: Date.now(),
      },
    ));
  });

  it("rejects later joinedAt mutations", async () => {
    const listenerDb = testEnv.authenticatedContext("listener").database();

    await assertFails(set(
      ref(listenerDb, "parties/p/participants/listener/joinedAt"),
      0,
    ));
  });

  it("allows party members to send messages as themselves", async () => {
    const listenerDb = testEnv.authenticatedContext("listener").database();
    const validMessage = {
      uid: "listener",
      name: "Listener",
      photoUrl: "",
      message: "Hello",
      timestamp: serverTimestamp(),
    };

    await assertSucceeds(set(
      ref(listenerDb, "parties/p/chat/message"),
      validMessage,
    ));
  });

  it("rejects chat writes from non-members", async () => {
    const outsiderDb = testEnv.authenticatedContext("outsider").database();
    const validMessage = {
      uid: "outsider",
      name: "Outsider",
      photoUrl: "",
      message: "Hello",
      timestamp: serverTimestamp(),
    };

    await assertFails(set(
      ref(outsiderDb, "parties/p/chat/message"),
      validMessage,
    ));
  });

  it("rejects party deletion by listeners", async () => {
    const listenerDb = testEnv.authenticatedContext("listener").database();

    await assertFails(remove(ref(listenerDb, "parties/p")));
  });

  it("allows party deletion by the host", async () => {
    const hostDb = testEnv.authenticatedContext("host").database();

    await assertSucceeds(remove(ref(hostDb, "parties/p")));
  });

  it("allows the current host to transfer the whole room to an existing listener", async () => {
    const hostDb = testEnv.authenticatedContext("host").database();

    await assertSucceeds(set(
      ref(hostDb, "parties/p"),
      transferredParty(),
    ));
  });

  it("rejects a host transfer attempted by a listener", async () => {
    const listenerDb = testEnv.authenticatedContext("listener").database();

    await assertFails(set(
      ref(listenerDb, "parties/p"),
      transferredParty(),
    ));
  });

  it("rejects a transfer that keeps the departing host", async () => {
    const hostDb = testEnv.authenticatedContext("host").database();

    await assertFails(set(
      ref(hostDb, "parties/p"),
      transferredParty({
        participants: {
          host: seededParticipant("Host", 1, false),
          listener: seededParticipant("Listener", 2, true),
        },
      }),
    ));
  });

  it("rejects promotion of a participant absent from the old room", async () => {
    const hostDb = testEnv.authenticatedContext("host").database();

    await assertFails(set(
      ref(hostDb, "parties/p"),
      transferredParty({
        hostUid: "outsider",
        hostName: "Outsider",
        participants: {
          listener: seededParticipant("Listener", 2, false),
          outsider: seededParticipant("Outsider", 4, true),
        },
      }),
    ));
  });

  it("rejects a transfer that injects a new participant", async () => {
    const hostDb = testEnv.authenticatedContext("host").database();

    await assertFails(set(
      ref(hostDb, "parties/p"),
      transferredParty({
        participants: {
          listener: seededParticipant("Listener", 2, true),
          later: seededParticipant("Later", 3, false),
          outsider: seededParticipant("Outsider", 4, false),
        },
      }),
    ));
  });

  it("rejects a transfer whose host name does not match the promoted member", async () => {
    const hostDb = testEnv.authenticatedContext("host").database();

    await assertFails(set(
      ref(hostDb, "parties/p"),
      transferredParty({hostName: "Impostor"}),
    ));
  });

  it.each([
    ["status", {status: "ended"}],
    ["createdAt", {createdAt: 99}],
    ["playback state", {state: {isPlaying: false, positionSeconds: 0}}],
    ["queue", {queue: {injected: {title: "Injected"}}}],
    ["chat", {chat: {injected: {message: "Injected"}}}],
    ["unknown field", {injected: true}],
  ])("rejects unrelated %s changes during transfer", async (_label, change) => {
    const hostDb = testEnv.authenticatedContext("host").database();

    await assertFails(set(
      ref(hostDb, "parties/p"),
      transferredParty(change),
    ));
  });

  it.each([
    [
      "name",
      {
        hostName: "Renamed",
        participants: {
          listener: seededParticipant("Renamed", 2, true),
          later: seededParticipant("Later", 3, false),
        },
      },
    ],
    [
      "photo URL",
      {
        participants: {
          listener: {
            ...seededParticipant("Listener", 2, true),
            photoUrl: "changed",
          },
          later: seededParticipant("Later", 3, false),
        },
      },
    ],
    [
      "join time",
      {
        participants: {
          listener: seededParticipant("Listener", 99, true),
          later: seededParticipant("Later", 3, false),
        },
      },
    ],
  ])("rejects promoted participant %s mutation", async (_label, change) => {
    const hostDb = testEnv.authenticatedContext("host").database();

    await assertFails(set(
      ref(hostDb, "parties/p"),
      transferredParty(change),
    ));
  });

  it("rejects a second participant marked as host", async () => {
    const hostDb = testEnv.authenticatedContext("host").database();

    await assertFails(set(
      ref(hostDb, "parties/p"),
      transferredParty({
        participants: {
          listener: seededParticipant("Listener", 2, true),
          later: seededParticipant("Later", 3, true),
        },
      }),
    ));
  });

  it("preserves authenticated private-chat reads and writes", async () => {
    const listenerDb = testEnv.authenticatedContext("listener").database();

    await assertSucceeds(get(
      ref(listenerDb, "private_chats/host_listener/messages"),
    ));
    await assertSucceeds(set(
      ref(listenerDb, "private_chats/host_listener/messages/new"),
      {text: "reply", senderId: "listener", timestamp: serverTimestamp()},
    ));
  });

  it("rejects unauthenticated private-chat reads and writes", async () => {
    const unauthenticatedDb = testEnv.unauthenticatedContext().database();

    await assertFails(get(ref(unauthenticatedDb, "private_chats")));
    await assertFails(set(
      ref(unauthenticatedDb, "private_chats/chat/messages/new"),
      {text: "intrusion"},
    ));
  });

  it("preserves authenticated presence reads and self writes", async () => {
    const listenerDb = testEnv.authenticatedContext("listener").database();

    await assertSucceeds(get(ref(listenerDb, "status/listener/isOnline")));
    await assertSucceeds(set(ref(listenerDb, "status/listener"), {
      isOnline: false,
      lastSeen: serverTimestamp(),
    }));
  });

  it("rejects presence writes for another user", async () => {
    const outsiderDb = testEnv.authenticatedContext("outsider").database();

    await assertFails(set(ref(outsiderDb, "status/listener/isOnline"), false));
  });

  it("rejects unauthenticated presence reads and writes", async () => {
    const unauthenticatedDb = testEnv.unauthenticatedContext().database();

    await assertFails(get(ref(unauthenticatedDb, "status/listener")));
    await assertFails(set(
      ref(unauthenticatedDb, "status/listener/isOnline"),
      false,
    ));
  });
});
