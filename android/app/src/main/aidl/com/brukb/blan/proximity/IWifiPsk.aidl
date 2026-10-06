package com.brukb.blan.proximity;

interface IWifiPsk {
    String readPersonal(String ssidHint);
    /** True when [ssid] is a saved personal network. No passphrase in the reply. */
    boolean hasSaved(String ssid);
    /** Empty on miss. Never include the passphrase in the reply. */
    String connectPersonal(String ssid, String passphrase, String security);
    void destroy();
}
