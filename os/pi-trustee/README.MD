# Raspberry Pi 5 Trustee for Confidential Containers
This project is designed to bootstrap a Raspberry Pi 5 with a custom lightweight immutable OS that strictly runs the components for validating confidential container attestations. It runs:
1. Trustee KBS - main interface for incoming requests and acts as a relying party in RATS model
1. AS CoCo - Confidential Container Attestation Service which is the verifier component in RATS model and veries TEE evidence
1. RSVP - Reference Value Provider Service which holds the all the known good measurements for hardware. These values must be secure.

## Why Raspberry Pi 5 for Trustee?
For this particular configuration, the raspberry pi 5 is being considered the trust anchor for the overall hyposcalar environment. It will NOT be the primary holder of secrets or act as the mediator to hardware backed secrets. Its purpose is to validate that the core CA (OpenBao in this case) is running in a secured environment in a confidential container before releasing the pin that will unlock the hardware backed key material (YubiKey in this architecture). While the pi 5 may lack physical tamper resitant hardware and physical memory isolation, it does allow for secureboot and has the ability to store an encryption key to a LUKS partition during OTP provisioning. So if an attacker has direct physical access to the device, they could read those values out of ram to get access to the encrypted values. 

For the sake of this project, this level of compromise is acceptable and still provides a split responsibility model where stealing the pi 5 without the yubikey connected machine just leaks the pin to the yubikey and stealing/gaining access to just the server without the raspberry pi will not allow openbao to run or access any senstive secrets. In a more robust environment, these components would be backed by more capable HSMs and trust anchor would be silicon based direct from a manufacturer. In this model, securing the pi 5 via secure boot is the "manufacturing process" in this model.

## Key requirments
### Paritioning
It is absolutely crucial that the storage for the pi 5 be split into at least 4 paritions:
1. Boot partition that holds essentially the initramfs
1. Primary os partition that is the read only root file system
1. Secondary os partition for performing os updates and ota
1. Configuration and secret partition which is encrypted and stores any durable information required by the Trustee ecosystem

The os partition is chosen as read only and will be verified with dm-verity on boot. A read only partition is chosen to ensure the os is immutable and is not encrypted for both simplicity and performance since there is no sensistive information in the root fs itself.

To ensure that the root fs can be read only, any configuration or secrets must have an encrypted partition to live so that data is not extractable at rest.

### OS
The operating system should remain as lightweight as possible to minimize surface areas for potential compromise since this is acting as the core trust anchor. The only services outside the linux kernel and hardware drivers required are the KBS, AS and RSVP services and their dependencies. The services can be launched via Docker or run via a Kubernetes operator. Some possibilities for OS include Talos linux, Headless Ubuntu, etc. For the purposes of this project, a yocto oriented build has been chosen. This provides some level of control over the build process, can be run in a TEE built and signed in a trusted build container and can be performed without runtime emulation for an arm environment.

The yocto image is based on the core meta-yocto layer and the meta-raspberrypi layer found here: https://github.com/agherzan/meta-raspberrypi It is an approved layer with the Yocto Project Compatible Layers Program.

### Trustee
All images/libraries/containers for the Trustee ecosystem are pulled directly from source https://github.com/confidential-containers/trustee
