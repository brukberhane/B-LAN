package com.brukb.blan.proximity;

interface IWifiPsk {
    String readPersonal(String ssidHint);
    /** Empty on miss. Never include the passphrase in the reply. */
    String connectPersonal(String ssid, String passphrase, String security);
    void destroy();
}
