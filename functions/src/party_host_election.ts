export type PartyParticipant = {
  name: string;
  joinedAt: number;
  isHost: boolean;
  photoUrl?: string;
};

export type PartyRecord = {
  hostUid: string;
  hostName: string;
  participants: Record<string, PartyParticipant>;
  [key: string]: unknown;
};

export type DepartureResolution =
  | {action: "noop"}
  | {action: "delete"}
  | {action: "promote"; party: PartyRecord; promotedUid: string};

export function resolveHostDeparture(
  party: PartyRecord | null,
  departedUid: string,
): DepartureResolution {
  if (party === null || party.hostUid !== departedUid) return {action: "noop"};
  const remaining = Object.entries(party.participants ?? {});
  if (remaining.length === 0) return {action: "delete"};
  remaining.sort(([uidA, a], [uidB, b]) =>
    a.joinedAt - b.joinedAt || uidA.localeCompare(uidB));
  const [promotedUid, promoted] = remaining[0];
  const participants = Object.fromEntries(remaining.map(([uid, member]) => [
    uid,
    {...member, isHost: uid === promotedUid},
  ]));
  return {
    action: "promote",
    promotedUid,
    party: {...party, hostUid: promotedUid, hostName: promoted.name, participants},
  };
}
