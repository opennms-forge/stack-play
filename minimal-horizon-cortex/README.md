# Usage

You have to compile first the OpenNMS Cortex Time Series plugin from [here](https://github.com/OpenNMS/opennms-cortex-tss-plugin).
The build artifact is a KAR file in `opennms-cortex-tss-plugin/assembly/kar/target/opennms-cortex-tss-plugin.kar`.

Copy the KAR file in `./container-fs/horizon/opt/opennms/deploy/opennms-cortex-tss-plugin.kar`
Start the stack with `docker-compose up -d` and the feature opennms-plugin-cortex-tss should be started automatically via the features boot configuration:

```
ssh admin@karaflocal -p 8101 "feature:list | grep opennms-plugins-cortex-tss"
Warning: Permanently added '[127.0.0.1]:8101' (RSA) to the list of known hosts.
Password authentication
Password:
opennms-plugins-cortex-tss                  | 1.0.0.SNAPSHOT   | x        | Started     | openmms-plugins-cortex-tss-features | OpenNMS :: Plugins :: Cortex TSS
```
