package itemutilities;

/** Keep exact item identity; never guess between different infusion identities. */
class EquipmentPresetMatch {
    public static function choose(uid:String, fingerprint:String,
        candidates:Array<{uid:String, fingerprint:String}>):Int {
        var match = -1;
        var matchingUid = -1;
        var ambiguous = false;
        for (i in 0...candidates.length) {
            var item = candidates[i];
            if (ItemLockState.fingerprintMatches(fingerprint, item.fingerprint)) {
                // __uid is a session/network ID, not a persistent item ID. A
                // later login can assign it to an entirely different item.
                if (uid != null && uid != "" && item.uid == uid) matchingUid = i;
                if (match < 0) match = i;
                else if (item.fingerprint != candidates[match].fingerprint) ambiguous = true;
            }
        }
        // Preserve existing handling of interchangeable gear (e.g. two equal
        // rings); callers exclude slots already assigned to another item.
        // A reused UID cannot disambiguate legacy saves that omitted infusions.
        return ambiguous ? -1 : matchingUid >= 0 ? matchingUid : match;
    }
}
