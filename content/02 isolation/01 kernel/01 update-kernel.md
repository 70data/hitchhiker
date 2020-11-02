查看现有内核版本

```
# uname -r
3.10.0-1127.19.1.el7.x86_64

# cat /proc/version
Linux version 3.10.0-1127.19.1.el7.x86_64 (mockbuild@kbuilder.bsys.centos.org) (gcc version 4.8.5 20150623 (Red Hat 4.8.5-39) (GCC) )
```

查看默认启动的内核

```
#  grub2-editenv list
saved_entry=CentOS Linux (3.10.0-1127.19.1.el7.x86_64) 7 (Core)

# awk -F \' '$1=="menuentry " {print i++ " : " $2}' /etc/grub2.cfg
0 : CentOS Linux (3.10.0-1127.19.1.el7.x86_64) 7 (Core)
1 : CentOS Linux (3.10.0-1127.el7.x86_64) 7 (Core)
2 : CentOS Linux (0-rescue-20200914151306980406746494236010) 7 (Core)
```

下载内核安装包

```
wget http://mirror.centos.org/altarch/7/kernel/x86_64/Packages/kernel-5.4.65-200.el7.x86_64.rpm

wget http://mirror.centos.org/altarch/7/kernel/x86_64/Packages/kernel-core-5.4.65-200.el7.x86_64.rpm

wget http://mirror.centos.org/altarch/7/kernel/x86_64/Packages/kernel-modules-5.4.65-200.el7.x86_64.rpm

wget http://mirror.centos.org/altarch/7/kernel/x86_64/Packages/kernel-headers-5.4.65-200.el7.x86_64.rpm

wget http://mirror.centos.org/altarch/7/kernel/x86_64/Packages/kernel-devel-5.4.65-200.el7.x86_64.rpm

http://mirror.centos.org/altarch/7/kernel/x86_64/Packages/kernel-tools-5.4.65-200.el7.x86_64.rpm

http://mirror.centos.org/altarch/7/kernel/x86_64/Packages/kernel-tools-libs-5.4.65-200.el7.x86_64.rpm

http://mirror.centos.org/altarch/7/kernel/x86_64/Packages/perf-5.4.65-200.el7.x86_64.rpm

http://mirror.centos.org/altarch/7/kernel/x86_64/Packages/python3-perf-5.4.65-200.el7.x86_64.rpm
```

安装内核

```
yum install kernel-core-5.4.65-200.el7.x86_64.rpm

yum install kernel-modules-5.4.65-200.el7.x86_64.rpm

yum install kernel-5.4.65-200.el7.x86_64.rpm

yum install kernel-devel-5.4.65-200.el7.x86_64.rpm

yum install kernel-headers-5.4.65-200.el7.x86_64.rpm

yum install perf-5.4.65-200.el7.x86_64.rpm

yum install python3-perf-5.4.65-200.el7.x86_64.rpm
```

修改默认启动内核

```
grub2-set-default 'CentOS Linux (5.4.65-200.el7.x86_64) 7 (Core)'

# grub2-editenv list
saved_entry=CentOS Linux (5.4.65-200.el7.x86_64) 7 (Core)

# grubby --update-kernel /boot/vmlinuz-5.4.65-200.el7.x86_64 --args="systemd.unified_cgroup_hierarchy=0"
```

重启

```
reboot
```

查看现有内核版本

```
# uname -r
5.4.65-200.el7.x86_64

# cat /proc/version
Linux version 5.4.65-200.el7.x86_64 (mockbuild@x86-02.bsys.centos.org) (gcc version 8.3.1 20190311 (Red Hat 8.3.1-3) (GCC))
```

