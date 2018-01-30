# MediaWiki - Remote backup

## Description
Shell script for MediaWiki backup on remote site.

The execution is executed in two moments:

1o. Creating tarball with application files and dump.DB;

2nd. Synchronization of the tarball in a remote machine;

Important:

an. For file transfers over ssh it is necessary to ensure a trust relationship in exchange for RSA / DSA keys;

B. To monitor the routine through email, it is necessary a client to configure some smtp (ex posftix);


```
            +-----------------+  +                                            + +-------------------+            +-------------------+
            |                 |  |                                            | |                   |            |                   |
            |  MEDIAWIKI-DST  |  |  +-----------> XXXXXXXXXXXXXX +----------> | |   MEDIAWIKI-SRC   | +--------> |   MEDIAWIKI-SRC   |
            |   10.81.1.221   |  |    ssh/22      X  internet  X   ssh/22     | |  192.168.105.172  | mysql/3306 |  192.168.105.173  |
            |                 |  |  <-----------+ XXXXXXXXXXXXXX <----------+ | |        app        | <--------+ |         bd        |
            +-----------------+  |                                            | +-------------------+            +-------------------+
            root@10.81.1.221:22  |              # --- Inicio --- #            | userssh@192.168.105.172:22
      ~/backupMediaWIki.sync.sh  |                                            | ~/backupMediaWIki.dump.sh

                                 |                                            |
1. Ask to pack tarball;          |  +-------------------------------------->  | 2. Tarball is packaged
   a. Ask submited by SSH;       |                                            |    a. App files (gz)
                                 |                                            |    b. Dumping DB (gz)
3. Remaneja tarball remoto:      |                                            |    c. Packaging gz
   a. Receive okay;              |  <--------------------------------------+  |    d. Check file
   b. Sync (scp);                |                                            |    e. Send mail
   c. Calcula e compara hashMD4; |                                            |
   d. Send mail;                 +                # --- End --- #             +

```
## Scheduling / Job

- Frequency: Daily;
- Time: 06H00;
- Job: /home/userssh/JobBackupMediaWikiSRC.sh
- Location: root@10.81.1.221

## Source of backup

- End IP Application: 192.168.105.172
- End IP Database:    192.168.105.173
- Dir Application:    /usr/local/mediawiki-1.23.5
- DBName:             WIKI
- DBUser:              mediawiki

## Destiny

- End IP Destination: 10.81.1.221 (remote infrastructure)
- Dir Destination Backup: / var / backups / MediaWikiSRC
