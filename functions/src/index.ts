import {initializeApp} from "firebase-admin/app";
import {logger, setGlobalOptions} from "firebase-functions";
import {onValueDeleted} from "firebase-functions/database";
import {PartyRecord, resolveHostDeparture} from "./party_host_election";

initializeApp();
setGlobalOptions({
  region: process.env.FUNCTIONS_EMULATOR === "true" ?
    "us-central1" : "asia-southeast1",
  maxInstances: 10,
});

export const onPartyParticipantDeleted = onValueDeleted(
  "/parties/{partyId}/participants/{uid}",
  async (event) => {
    const {partyId, uid} = event.params;
    const partyRef = event.data.ref.parent?.parent;
    if (!partyRef) {
      logger.error("party participant departure path was invalid", {
        partyId,
        departedUid: uid,
      });
      return;
    }
    let loggedAction: "noop" | "delete" | "promote" = "noop";
    let promotedUid: string | undefined;
    await partyRef.transaction((current: PartyRecord | null) => {
      if (current === null) return null;
      const resolution = resolveHostDeparture(current, uid);
      loggedAction = resolution.action;
      if (resolution.action === "noop") return;
      if (resolution.action === "delete") return null;
      promotedUid = resolution.promotedUid;
      return resolution.party;
    });
    logger.info("party participant departure resolved", {
      partyId,
      departedUid: uid,
      action: loggedAction,
      promotedUid,
    });
  },
);
