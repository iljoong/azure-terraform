# Packer

> It is recommended to use azure-cli or managed service identity (MSI) for authentication. See packer [document](https://www.packer.io/plugins/builders/azure) for more information.

Create nginx image

```
packer inspect lx_nginx.json

packer build -var rgname=demo-rg -var imagename=nximg001 lx_nginx.json
```
