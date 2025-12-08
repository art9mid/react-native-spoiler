#include <jni.h>
#include "NitroSpoilerOnLoad.hpp"

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
  return margelo::nitro::spoiler::initialize(vm);
}
