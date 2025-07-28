extern "C" void kernel_main() {
    const char* msg = "Hello from C++ Kernel!";
    char* video = (char*)0xb8000;
    for (int i = 0; msg[i] != 0; ++i) {
        video[i * 2] = msg[i];
        video[i * 2 + 1] = 0x0F;
    }
    while (true);
}
