const protocolVersion = 1;
const serviceType = '_blan._tcp';
const defaultHttpPort = 59487;
const defaultChunkSizeDesktop = 32 * 1024 * 1024;
const defaultChunkSizeAndroid = 16 * 1024 * 1024;
const maxConcurrentDownloads = 3;
const hashAlgorithm = 'sha256';

int defaultChunkSizeForPlatform({required bool isAndroid}) =>
    isAndroid ? defaultChunkSizeAndroid : defaultChunkSizeDesktop;
