import {describe, expect, it} from "vitest";
import {resolveHostDeparture} from "../src/party_host_election";

describe("resolveHostDeparture", () => {
  it("deletes a party when the departing host was alone", () => {
    expect(resolveHostDeparture({
      hostUid: "host",
      hostName: "Host",
      participants: {},
    }, "host")).toEqual({action: "delete"});
  });

  it("promotes the earliest member and resets every host flag", () => {
    const result = resolveHostDeparture({
      hostUid: "host",
      hostName: "Host",
      participants: {
        later: {name: "Later", joinedAt: 200, isHost: false},
        oldest: {name: "Oldest", joinedAt: 100, isHost: false},
      },
    }, "host");
    expect(result.action).toBe("promote");
    if (result.action !== "promote") throw new Error("expected promotion");
    expect(result.party.hostUid).toBe("oldest");
    expect(result.party.participants.oldest.isHost).toBe(true);
    expect(result.party.participants.later.isHost).toBe(false);
  });

  it("uses uid as the stable tie-breaker", () => {
    const result = resolveHostDeparture({
      hostUid: "host",
      hostName: "Host",
      participants: {
        zed: {name: "Zed", joinedAt: 100, isHost: false},
        alpha: {name: "Alpha", joinedAt: 100, isHost: false},
      },
    }, "host");
    expect(result.action === "promote" && result.party.hostUid).toBe("alpha");
  });

  it("does not rewrite host state when a listener leaves", () => {
    expect(resolveHostDeparture({
      hostUid: "host",
      hostName: "Host",
      participants: {host: {name: "Host", joinedAt: 1, isHost: true}},
    }, "listener")).toEqual({action: "noop"});
  });
});
