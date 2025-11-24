import 'dart:ffi';
import 'dart:io';

base class CsAttestResult extends Struct {
  @Uint8()
  external int ok;

  @Uint32()
  external int flags;

  @Array<Uint8>(16)
  external Array<Uint8> nonce;

  @Array<Uint8>(32)
  external Array<Uint8> token;
}

typedef _NativeAttestFn = CsAttestResult Function();
typedef _DartAttestFn = CsAttestResult Function();

class CsAttestation {
  late final DynamicLibrary lib;
  late final _DartAttestFn attestFn;

  CsAttestation() {
    if (!Platform.isAndroid) {
      throw Exception("Unsupported");
    }
    lib = DynamicLibrary.open("libcolourswift_av.so");
    attestFn = lib.lookupFunction<_NativeAttestFn, _DartAttestFn>("cs_attest_entry");
  }

  CsAttestResult run() {
    return attestFn();
  }
}
