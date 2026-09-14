package dpsmeter;

import dpsmeter.FightHistory.HistoryRequest;

class HistoryRequests {
    /** Adjacent reads may be superseded; explicitly requested deletions may not. */
    public static function coalesce(requests:Array<HistoryRequest>):Array<HistoryRequest> {
        var result:Array<HistoryRequest> = [];
        for (request in requests) {
            if (request.action != "delete" && result.length > 0 && result[result.length - 1].action != "delete")
                result[result.length - 1] = request;
            else result.push(request);
        }
        return result;
    }
}
