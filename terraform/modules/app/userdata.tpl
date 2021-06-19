#cloud-config

hostname: ${hostname}
fqdn: ${hostname}.${resolvers}

# Enable root account.
disable_root: false

locale: en_US.utf8
timezone: UTC

packages:
 - epel-release
 - lvm2

bootcmd:
 - /bin/sed -i -e 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

runcmd:
 - "/usr/local/bin/bootstrap.sh  >> /tmp/bootstrap.log"

puppet:
write_files:
 - path: "/usr/local/bin/bootstrap.sh"
   permissions: "0777"
   owner: "root:root"
   content: |
     #!/bin/bash
     set -x

     # Disable iptables.
     /sbin/service iptables stop
     /sbin/chkconfig iptables off

     # Update hosts in order to support 'facter fqdn'.
     /sbin/ip addr list eth0 | \
     sed -ne 's!^.*inet \([^/]*\).*$!\1  ${hostname} ${hostname}.${resolvers}!p' >> /etc/hosts

     # Configure motd.
     (
     echo
     echo "Hostname:  ${hostname}"
     echo
     ) > /etc/motd


     # Configure resolv.conf.
     sed -i -e 's/search.*/search ${resolvers}/' /etc/resolv.conf

     # Configure dhclient to not overwrite resolv.conf search order on reboot.
     ( echo ; echo 'supersede domain-search "${resolvers}";' ) \
     >> /etc/dhcp/dhclient-eth0.conf


     # configure storage for /usr/local/srini.
     if [ -e /dev/xvdb ] ; then
        /sbin/pvcreate /dev/xvdb
        /sbin/vgcreate vg-srini /dev/xvdb
        /sbin/vgchange -a y vg-srini
        /sbin/lvcreate -l 85%FREE -n lv-usr-local-pmc vg-srini
        /sbin/mke2fs -t ext4 /dev/vg-srini/lv-usr-local-pmc
        mkdir -p /usr/local/srini
        echo -e "/dev/vg-srini/lv-usr-local-pmc\t/usr/local/srini\text4\tdefaults\t1 2" >> /etc/fstab
        mount /usr/local/srini
     fi
