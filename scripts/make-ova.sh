#!/bin/sh
# Makes a VirtualBox appliance (.ova) from the ISO and the disk image.
# Importing it (File > Import Appliance, or VBoxManage import) creates a VM
# with the right storage controller and network card, the ISO in the
# optical drive and the disk attached.
#
# Usage: make-ova.sh <out.ova> <name> <iso> <disk.img> <memory MB>
#                    <disk: virtio-scsi|ahci> <nic: virtio|e1000|none>
#                    <usb: y|n>
#
# The descriptor follows what 'VBoxManage export --options iso' writes
# (VirtualBox 7.2). The vbox:Machine part holds the settings that standard
# OVF cannot describe, e.g. the virtio-net network card.
set -eu

out=$1 name=$2 iso=$3 img=$4 mem=$5 disk=$6 nic=$7 usb=$8

tmp=$(mktemp -d "${out%/*}/ova.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

iso_f=$name.iso
vmdk_f=$name-disk.vmdk
cp "$iso" "$tmp/$iso_f"
qemu-img convert -f raw -O vmdk -o subformat=streamOptimized "$img" "$tmp/$vmdk_f"
iso_size=$(stat -c %s "$iso")
img_size=$(stat -c %s "$img")

case $disk in
virtio-scsi)
    ctl_caption=virtioSCSIController0 ctl_desc="VirtioSCSI Controller"
    ctl_sub=VirtioSCSI ctl_name=VirtIO ctl_type=VirtioSCSI ;;
ahci)
    ctl_caption=sataController0 ctl_desc="SATA Controller"
    ctl_sub=AHCI ctl_name=SATA ctl_type=AHCI ;;
*)
    echo "make-ova.sh: VirtualBox has no '$disk' disk controller" >&2
    exit 1 ;;
esac

case $nic in
virtio) nic_type=virtio ;;
e1000) nic_type=82540EM ;;
none) nic_type= ;;
*) echo "make-ova.sh: unknown network card '$nic'" >&2; exit 1 ;;
esac

# Fixed ids: VirtualBox makes new ones when it imports the appliance.
ISO_UUID=5d3c1f0e-7a52-4c1b-9a0e-2b6f8a1c0001
DISK_UUID=5d3c1f0e-7a52-4c1b-9a0e-2b6f8a1c0002
VM_UUID=5d3c1f0e-7a52-4c1b-9a0e-2b6f8a1c0003

{
cat <<EOF
<?xml version="1.0"?>
<Envelope ovf:version="1.0" xml:lang="en-US" xmlns="http://schemas.dmtf.org/ovf/envelope/1" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:vbox="http://www.virtualbox.org/ovf/machine">
  <References>
    <File ovf:id="file1" ovf:href="$iso_f"/>
    <File ovf:id="file2" ovf:href="$vmdk_f"/>
  </References>
  <DiskSection>
    <Info>List of the virtual disks used in the package</Info>
    <Disk ovf:capacity="$iso_size" ovf:diskId="iso1" ovf:fileRef="file1" ovf:format="http://www.ecma-international.org/publications/standards/Ecma-119.htm" vbox:uuid="$ISO_UUID"/>
    <Disk ovf:capacity="$img_size" ovf:diskId="vmdisk2" ovf:fileRef="file2" ovf:format="http://www.vmware.com/interfaces/specifications/vmdk.html#streamOptimized" vbox:uuid="$DISK_UUID"/>
  </DiskSection>
EOF
if [ -n "$nic_type" ]; then cat <<EOF
  <NetworkSection>
    <Info>Logical networks used in the package</Info>
    <Network ovf:name="NAT">
      <Description>Logical network used by this appliance.</Description>
    </Network>
  </NetworkSection>
EOF
fi
cat <<EOF
  <VirtualSystem ovf:id="$name">
    <Info>A virtual machine</Info>
    <ProductSection>
      <Info>Meta-information about the installed software</Info>
      <Product>SmallHam Linux</Product>
      <ProductUrl>https://github.com/dandidev/smallham-linux</ProductUrl>
    </ProductSection>
    <OperatingSystemSection ovf:id="102">
      <Info>The kind of installed guest operating system</Info>
      <Description>Other_64</Description>
      <vbox:OSType ovf:required="false">Linux_64</vbox:OSType>
    </OperatingSystemSection>
    <VirtualHardwareSection>
      <Info>Virtual hardware requirements for a virtual machine</Info>
      <System>
        <vssd:ElementName>Virtual Hardware Family</vssd:ElementName>
        <vssd:InstanceID>0</vssd:InstanceID>
        <vssd:VirtualSystemIdentifier>$name</vssd:VirtualSystemIdentifier>
        <vssd:VirtualSystemType>virtualbox-2.2</vssd:VirtualSystemType>
      </System>
      <Item>
        <rasd:Caption>1 virtual CPU</rasd:Caption>
        <rasd:Description>Number of virtual CPUs</rasd:Description>
        <rasd:ElementName>1 virtual CPU</rasd:ElementName>
        <rasd:InstanceID>1</rasd:InstanceID>
        <rasd:ResourceType>3</rasd:ResourceType>
        <rasd:VirtualQuantity>1</rasd:VirtualQuantity>
      </Item>
      <Item>
        <rasd:AllocationUnits>MegaBytes</rasd:AllocationUnits>
        <rasd:Caption>$mem MB of memory</rasd:Caption>
        <rasd:Description>Memory Size</rasd:Description>
        <rasd:ElementName>$mem MB of memory</rasd:ElementName>
        <rasd:InstanceID>2</rasd:InstanceID>
        <rasd:ResourceType>4</rasd:ResourceType>
        <rasd:VirtualQuantity>$mem</rasd:VirtualQuantity>
      </Item>
      <Item>
        <rasd:Address>0</rasd:Address>
        <rasd:Caption>ideController0</rasd:Caption>
        <rasd:Description>IDE Controller</rasd:Description>
        <rasd:ElementName>ideController0</rasd:ElementName>
        <rasd:InstanceID>3</rasd:InstanceID>
        <rasd:ResourceSubType>PIIX4</rasd:ResourceSubType>
        <rasd:ResourceType>5</rasd:ResourceType>
      </Item>
      <Item>
        <rasd:Address>1</rasd:Address>
        <rasd:Caption>ideController1</rasd:Caption>
        <rasd:Description>IDE Controller</rasd:Description>
        <rasd:ElementName>ideController1</rasd:ElementName>
        <rasd:InstanceID>4</rasd:InstanceID>
        <rasd:ResourceSubType>PIIX4</rasd:ResourceSubType>
        <rasd:ResourceType>5</rasd:ResourceType>
      </Item>
      <Item>
        <rasd:Address>0</rasd:Address>
        <rasd:Caption>$ctl_caption</rasd:Caption>
        <rasd:Description>$ctl_desc</rasd:Description>
        <rasd:ElementName>$ctl_caption</rasd:ElementName>
        <rasd:InstanceID>5</rasd:InstanceID>
        <rasd:ResourceSubType>$ctl_sub</rasd:ResourceSubType>
        <rasd:ResourceType>20</rasd:ResourceType>
      </Item>
      <Item>
        <rasd:AddressOnParent>0</rasd:AddressOnParent>
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Caption>cdrom1</rasd:Caption>
        <rasd:Description>CD-ROM Drive</rasd:Description>
        <rasd:ElementName>cdrom1</rasd:ElementName>
        <rasd:HostResource>ovf:/disk/iso1</rasd:HostResource>
        <rasd:InstanceID>6</rasd:InstanceID>
        <rasd:Parent>4</rasd:Parent>
        <rasd:ResourceType>15</rasd:ResourceType>
      </Item>
      <Item>
        <rasd:AddressOnParent>0</rasd:AddressOnParent>
        <rasd:Caption>disk2</rasd:Caption>
        <rasd:Description>Disk Image</rasd:Description>
        <rasd:ElementName>disk2</rasd:ElementName>
        <rasd:HostResource>ovf:/disk/vmdisk2</rasd:HostResource>
        <rasd:InstanceID>7</rasd:InstanceID>
        <rasd:Parent>5</rasd:Parent>
        <rasd:ResourceType>17</rasd:ResourceType>
      </Item>
EOF
if [ -n "$nic_type" ]; then cat <<EOF
      <Item>
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Caption>Ethernet adapter on 'NAT'</rasd:Caption>
        <rasd:Connection>NAT</rasd:Connection>
        <rasd:ElementName>Ethernet adapter on 'NAT'</rasd:ElementName>
        <rasd:InstanceID>8</rasd:InstanceID>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
EOF
fi
cat <<EOF
    </VirtualHardwareSection>
    <vbox:Machine ovf:required="false" version="1.19-linux" uuid="{$VM_UUID}" name="$name" OSType="Linux_64" snapshotFolder="Snapshots">
      <ovf:Info>Complete VirtualBox machine configuration in VirtualBox format</ovf:Info>
      <Hardware>
        <Memory RAMSize="$mem"/>
        <Boot>
          <Order position="1" device="DVD"/>
          <Order position="2" device="HardDisk"/>
          <Order position="3" device="None"/>
          <Order position="4" device="None"/>
        </Boot>
        <Display VRAMSize="9"/>
        <Firmware/>
        <BIOS>
          <IOAPIC enabled="true"/>
          <SmbiosUuidLittleEndian enabled="true"/>
          <AutoSerialNumGen enabled="true"/>
        </BIOS>
EOF
if [ "$usb" = y ]; then cat <<EOF
        <USB>
          <Controllers>
            <Controller name="xHCI" type="XHCI"/>
          </Controllers>
        </USB>
EOF
fi
if [ -n "$nic_type" ]; then cat <<EOF
        <Network>
          <Adapter slot="0" enabled="true" type="$nic_type">
            <NAT/>
          </Adapter>
        </Network>
EOF
fi
cat <<EOF
        <AudioAdapter useDefault="true"/>
        <Clipboard/>
        <StorageControllers>
          <StorageController name="IDE" type="PIIX4" PortCount="2" useHostIOCache="true" Bootable="true">
            <AttachedDevice passthrough="false" type="DVD" hotpluggable="false" port="1" device="0">
              <Image uuid="{$ISO_UUID}"/>
            </AttachedDevice>
          </StorageController>
          <StorageController name="$ctl_name" type="$ctl_type" PortCount="1" useHostIOCache="false" Bootable="true">
            <AttachedDevice type="HardDisk" hotpluggable="false" port="0" device="0">
              <Image uuid="{$DISK_UUID}"/>
            </AttachedDevice>
          </StorageController>
        </StorageControllers>
        <RTC localOrUTC="UTC"/>
        <CPU>
          <HardwareVirtExLargePages enabled="false"/>
          <PAE enabled="true"/>
          <LongMode enabled="true"/>
          <X2APIC enabled="true"/>
        </CPU>
      </Hardware>
    </vbox:Machine>
  </VirtualSystem>
</Envelope>
EOF
} > "$tmp/$name.ovf"

(cd "$tmp" && for f in "$name.ovf" "$iso_f" "$vmdk_f"; do
    echo "SHA256 ($f) = $(sha256sum < "$f" | cut -d' ' -f1)"
done > "$name.mf")

# The descriptor must be the first file in the archive, then the manifest.
rm -f "$out"
tar --format=ustar --owner=0 --group=0 --numeric-owner -C "$tmp" \
    -cf "$out" "$name.ovf" "$name.mf" "$iso_f" "$vmdk_f"
