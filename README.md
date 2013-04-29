Commotion-apps
==============

Commotion-apps contains an LuCI application portal for OpenWRT, as well as a script to check for new applications nearby on the network.

The LuCI application portal adds some pages to the Commotion OpenWRT menu. The main page shows all local applications on the mesh that have been approved by the node administrator. There are also pages for creating an application, as well as administrator pages for approving/blacklisting apps and changing settings related to applications.

Advertising applications
------------------------
Applications are advertised on a Commotion mesh network using Avahi/mDNS. Each application should have a `.service` file in the `/etc/avahi/services/` directory. The structure of the service file should follow this template:

    <?xml version="1.0" standalone='no'?><!--*-nxml-*-->
    <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
    
    <!-- This file is part of commotion -->
    <!-- Reference: http://en.gentoo-wiki.com/wiki/Avahi#Custom_Services -->
    <!-- Reference: http://wiki.xbmc.org/index.php?title=Avahi_Zeroconf -->
    
    <service-group>
      <name replace-wildcards="yes">Service Name on %h</name>
    
      <service>
        <type>_https._tcp</type> <!-- _svc-type.sub-type._tcp|udp -->
        <domain-name>mesh.local</domain-name>
        <!--<host-name>%h.mesh.local</host-name>--> <!-- DON'T set hostname, because avahi will fail to resolve it when using mesh.local domain-->
        <port>443</port> <!--optional-->
        <txt-record>application=Example Application</txt-record>
        <txt-record>ttl=2</txt-record> <!--optional: how many hops away the service should be advertised-->
        <txt-record>ipaddr=https://commotionwireless.net</txt-record> <!-- IP address or URL of service host -->
        <txt-record>type=collaboration</txt-record>
        <txt-record>type=circumvention</txt-record> <!-- each type should have its own txt-record -->
        <txt-record>fingerprint=FA7E03D576F9A6752194CFCBE402C455B7F0F8C8894F7C05F17ECE500D2DC648</txt-record>
        <txt-record>signature=E07B1282AE1601C334CEA861DF795D57D00603BA00D97F382720F4146DDCD4427973D171C89BCA0EAAF1D72E9EF0DB2367CE07BBFFF6FF27FF01F1DFBEB65D0B</txt-record>
        <txt-record>icon=https://exampleapplication.com/icon.png</txt-record>
        <txt-record>description=Commotion is an open-source communication tool that uses mobile phones, computers, and other wireless devices to create decentralized mesh networks.</txt-record>
        
      </service>
    </service-group>
