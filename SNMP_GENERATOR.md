# snmp_generator

## 概要

snmp_exporter用に`snmp.yml`を作成する際`config-generator`を利用しています。

`generator.yml`を利用して`config-generator`で`snmp.yml`を作成する方法は公式ドキュメントを参照してください。

<https://github.com/prometheus/snmp_exporter/tree/main/generator>

## `generator.yml`

以下は`config-generator`で使用する`generator.yml`の内容です。

```yaml
modules:
  # Default IF-MIB interfaces table with ifIndex.
  if_mib:
    version: 2
    auth:
      community: SeichiNOCTestViewer
    walk: [sysUpTime, interfaces, ifXTable]
    lookups:
      - source_indexes: [ifIndex]
        lookup: ifAlias
      - source_indexes: [ifIndex]
        # Uis OID to avoid conflict with PaloAlto PAN-COMMON-MIB.
        lookup: 1.3.6.1.2.1.2.2.1.2 # ifDescr
      - source_indexes: [ifIndex]
        # Use OID to avoid conflict with Netscaler NS-ROOT-MIB.
        lookup: 1.3.6.1.2.1.31.1.1.1.1 # ifName
    overrides:
      ifAlias:
        ignore: true # Lookup metric
      ifDescr:
        ignore: true # Lookup metric
      ifName:
        ignore: true # Lookup metric
      ifType:
        type: EnumAsInfo

# NEC IX Router
#
# https://jpn.nec.com/univerge/ix/Manual/MIB/PICO-SMI-MIB.txt
# https://jpn.nec.com/univerge/ix/Manual/MIB/PICO-SMI-ID-MIB.txt
# https://jpn.nec.com/univerge/ix/Manual/MIB/PICO-IPSEC-FLOW-MONITOR-MIB.txt
  nec_ix:
    version: 2
    auth:
      community: SeichiNOCTestViewer
    walk:
      - picoSystem
      - picoIpSecFlowMonitorMIB
      - picoExtIfMIB
      - picoNetworkMonitorMIB
      - picoIsdnMIB
      - picoNgnMIB
      - picoMobileMIB
      - picoIPv4MIB
      - picoIPv6MIB

# Synology
#
# Synology MIBs can be found here:
#   http://www.synology.com/support/snmp_mib.php
#   http://dedl.synology.com/download/Document/MIBGuide/Synology_MIB_File.zip
#
# Tested on RS2414rp+ NAS
#
  synology:
    version: 2
    auth:
      community: SeichiSabaGoisuhYane
    walk:
      - interfaces
      - sysUpTime
      - ifXTable
      - laNames
      - laLoadInt
      - ssCpuUser
      - ssCpuSystem
      - ssCpuIdle
      - memory
      - hrStorage
      - 1.3.6.1.4.1.6574.1       # synoSystem
      - 1.3.6.1.4.1.6574.2       # synoDisk
      - 1.3.6.1.4.1.6574.3       # synoRaid
      - 1.3.6.1.4.1.6574.4       # synoUPS
      - 1.3.6.1.4.1.6574.5       # synologyDiskSMART
      - 1.3.6.1.4.1.6574.6       # synologyService
      - 1.3.6.1.4.1.6574.101     # storageIO
      - 1.3.6.1.4.1.6574.102     # spaceIO
      - 1.3.6.1.4.1.6574.104     # synologyiSCSILUN
    lookups:
      - source_indexes: [spaceIOIndex]
        lookup: spaceIODevice
        drop_source_indexes: true
      - source_indexes: [storageIOIndex]
        lookup: storageIODevice
        drop_source_indexes: true
      - source_indexes: [serviceInfoIndex]
        lookup: serviceName
        drop_source_indexes: true
      - source_indexes: [ifIndex]
        # Use OID to avoid conflict with Netscaler NS-ROOT-MIB.
        lookup: 1.3.6.1.2.1.31.1.1.1.1 # ifName
        drop_source_indexes: true
      - source_indexes: [diskIndex]
        lookup: diskID
        drop_source_indexes: true
      - source_indexes: [raidIndex]
        lookup: raidName
        drop_source_indexes: true
      - source_indexes: [laIndex]
        lookup: laNames
        drop_source_indexes: true
      - source_indexes: [hrStorageIndex]
        lookup: hrStorageDescr
        drop_source_indexes: true
    overrides:
      diskModel:
        type: DisplayString
      diskSMARTAttrName:
        type: DisplayString
      diskSMARTAttrStatus:
        type: DisplayString
      diskSMARTInfoDevName:
        type: DisplayString
      diskType:
        type: DisplayString
      ifType:
        type: EnumAsInfo
      modelName:
        type: DisplayString
      raidFreeSize:
        type: gauge
      raidName:
        type: DisplayString
      raidTotalSize:
        type: gauge
      serialNumber:
        type: DisplayString
      serviceName:
        type: DisplayString
      version:
        type: DisplayString

```
