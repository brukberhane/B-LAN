const protocolVersion = 1;
const serviceType = '_blan._tcp';
const defaultBrowserHttpPort = 59487;
const defaultPeerHttpsPort = 59488;
const defaultHttpPort = defaultBrowserHttpPort;
const peerSchemeHttps = 'https';
const peerSchemeHttp = 'http';
const defaultChunkSizeDesktop = 32 * 1024 * 1024;
const defaultChunkSizeAndroid = 16 * 1024 * 1024;
const maxConcurrentDownloads = 3;
const hashAlgorithm = 'sha256';

int defaultChunkSizeForPlatform({required bool isAndroid}) =>
    isAndroid ? defaultChunkSizeAndroid : defaultChunkSizeDesktop;
