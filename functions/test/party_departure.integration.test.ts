import {deleteApp, initializeApp} from "firebase-admin/app";
import {getDatabase} from "firebase-admin/database";
import {afterAll, beforeEach, describe, expect, it} from "vitest";

const projectId = "demo-gensokyo-music";
const app = initializeApp({
  projectId,
  databaseURL: "https://fake-server.firebaseio.com",
}, "party-departure-integration");
const database = getDatabase(app);

type Participant = {
  name: string;
  joinedAt: number;
  isHost: boolean;
};

function member(name: string, joinedAt: number, isHost: boolean): Participant {
  return {name, joinedAt, isHost};
}

function partyWith(participants: Record<string, Participant>) {
  const host = Object.entries(participants).find(([, participant]) =>
    participant.isHost);
  if (!host) throw new Error("party fixture requires a host");
  return {
    code: "ABC123",
    createdAt: 1,
    hostUid: host[0],
    hostName: host[1].name,
    participants,
    playlist: [],
    messages: {},
  };
}

async function waitFor(
  predicate: () => Promise<boolean>,
  timeoutMs = 5_000,
): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (await predicate()) return;
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error(`condition was not met within ${timeoutMs}ms`);
}

describe("party participant departure trigger", () => {
  let partyNumber = 0;

  beforeEach(async () => {
    await database.ref("parties").remove();
    partyNumber += 1;
  });

  afterAll(async () => {
    await database.ref("parties").remove();
    await deleteApp(app);
  });

  function partyRef() {
    return database.ref(`parties/task-2-${partyNumber}`);
  }

  it("deletes the room after its only host participant is removed", async () => {
    const party = partyRef();
    await party.set(partyWith({host: member("Host", 1, true)}));

    await party.child("participants/host").remove();

    await waitFor(async () => (await party.get()).exists() === false);
  });

  it("promotes the oldest remaining participant", async () => {
    const party = partyRef();
    await party.set(partyWith({
      host: member("Host", 1, true),
      first: member("First", 2, false),
      second: member("Second", 3, false),
    }));

    await party.child("participants/host").remove();

    await waitFor(async () =>
      (await party.child("hostUid").get()).val() === "first");
    expect((await party.child("hostName").get()).val()).toBe("First");
    expect((await party.child("participants/first/isHost").get()).val()).toBe(true);
    expect((await party.child("participants/second/isHost").get()).val()).toBe(false);
  });

  it("does not change host state when a non-host participant leaves", async () => {
    const party = partyRef();
    await party.set(partyWith({
      host: member("Host", 1, true),
      listener: member("Listener", 2, false),
    }));

    await party.child("participants/listener").remove();

    await waitFor(async () =>
      (await party.child("participants/listener").get()).exists() === false);
    await new Promise((resolve) => setTimeout(resolve, 500));
    expect((await party.child("hostUid").get()).val()).toBe("host");
    expect((await party.child("participants/host/isHost").get()).val()).toBe(true);
  });

  it("uses uid to break equal joinedAt ties", async () => {
    const party = partyRef();
    await party.set(partyWith({
      host: member("Host", 1, true),
      zed: member("Zed", 2, false),
      alpha: member("Alpha", 2, false),
    }));

    await party.child("participants/host").remove();

    await waitFor(async () =>
      (await party.child("hostUid").get()).val() === "alpha");
    expect((await party.child("participants/alpha/isHost").get()).val()).toBe(true);
    expect((await party.child("participants/zed/isHost").get()).val()).toBe(false);
  });

  it("ignores a duplicate departure after the host is already replaced", async () => {
    const party = partyRef();
    const departedHost = member("Host", 1, true);
    await party.set(partyWith({
      host: departedHost,
      first: member("First", 2, false),
      second: member("Second", 3, false),
    }));
    await party.child("participants/host").remove();
    await waitFor(async () =>
      (await party.child("hostUid").get()).val() === "first");

    await party.child("participants/host").set({...departedHost, isHost: false});
    await party.child("participants/host").remove();
    await new Promise((resolve) => setTimeout(resolve, 500));

    expect((await party.child("hostUid").get()).val()).toBe("first");
    expect((await party.child("participants/first/isHost").get()).val()).toBe(true);
    expect((await party.child("participants/second/isHost").get()).val()).toBe(false);
  });

  it("elects a valid host when host and member removals are concurrent", async () => {
    const party = partyRef();
    await party.set(partyWith({
      host: member("Host", 1, true),
      first: member("First", 2, false),
      second: member("Second", 3, false),
    }));

    await Promise.all([
      party.child("participants/host").remove(),
      party.child("participants/first").remove(),
    ]);

    await waitFor(async () =>
      (await party.child("hostUid").get()).val() === "second");
    expect((await party.child("participants/second/isHost").get()).val()).toBe(true);
    expect((await party.child("participants/host").get()).exists()).toBe(false);
    expect((await party.child("participants/first").get()).exists()).toBe(false);
  });
});
