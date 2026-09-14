package dpsmeter;

/** The persistence tests run without HashLink or network requests. Production
    uses src/dpsmeter/UploadSocket.hx, whose no-allocation init is HL-specific. */
class UploadSocket extends sys.net.Socket {
    public function new(secure:Bool, onProgress:Void->Void) {
        super();
        close();
        throw "History tests must not send HTTP requests.";
    }
}
