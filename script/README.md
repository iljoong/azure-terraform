# Custom Script

This script to configure NAT instance or Web(NGINX)

## Endcoding

For azure vm extension customscript, use `base64` to encode script

```
cat natscript.sh | base64 -w0
```

## Reference

https://github.com/Azure/azure-linux-extensions/tree/master/CustomScript
