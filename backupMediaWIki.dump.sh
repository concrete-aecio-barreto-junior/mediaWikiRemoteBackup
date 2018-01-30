#!/bin/bash
#set -x
 
# Title         : "backupMediaWIki.dump.sh"
# Description   : This script make a file with (app+db) backup to remote sync;
# Author        : Aecio Junior <aecio.barreto.junior@concrete.com.br>
# Date          : 28 de Agosto de 2015.
# Version       : 1.1 - Translated comments 
# Usage         : ./backupMediaWIki.dump.sh
 
##---- Config vars ----##

BDHost="192.168.105.173"
BDDataBase="WIKI"
BDUser="UsuarioOmitido"
BDPassword="SenhaOmitida"
UserSCP=userssh
ArquivoConfiguracoes="/usr/local/mediawiki-1.23.5/LocalSettings.php"
DirDocumentRootWiki="/usr/local/mediateste"
DirBackupTemp="/var/backups/MediaWiki"
DirLog="/var/log"
MailList="aeciojr@gmail.com"

##--- Script vars ---##

Basename="`basename $0`"
ArquivoLog="${DirLog}/${Basename}.log"
PrefixBackup="BkpMediaWiki"

##------ Functions ------------##

# Function to get date time 
_DataHora(){ date "+%Y%m%d_%H%M%S_$RANDOM"; }

# Function to print date time
_DataHoraPrint(){ date "+%Y/%m/%d %H:%M:%S"; }

# Function to print output log
_Print(){
   local Flag="$( echo $1 | tr [:lower:] [:upper:])"
   echo -e "\n`_DataHoraPrint` [ $Flag ] $2 \n"
}

# .. To [EN/DIS]able maintenence flag 
_FlagPHPBackup(){
   # Usage _FlagPHPBackup ON|OFF
   local RC=0
   if [ $# -eq 1 ]
   then
      local Op=$( echo $1 | tr [:lower:] [:upper:] )
      if [ "${Op}x" == "OFFx" ]; then
         { sudo sed -i '/$wgReadOnly/s/^/#/' $ArquivoConfiguracoes && echo "FlagBkp[ wgReadOnly ] DESATIVADA no $ArquivoConfiguracoes"; } || local RC=$?
      elif [ "${Op}x" == "ONx" ]; then
         { sudo sed -i 's/^#$wgReadOnly/$wgReadOnly/' $ArquivoConfiguracoes && echo "FlagBkp [ wgReadOnly ] ATIVADA no $ArquivoConfiguracoes"; } || local RC=$?
      else
         echo "Do supply argument ON|OFF"
         local RC=2
      fi
   else
      echo "Do supply argument ON|OFF"
      local RC=3
   fi
   return $RC
}

# Packaging app files tarball
_BackupSistemaArquivos(){
   local RC=0
   local Origem="${DirDocumentRootWiki}"
   local Destino="${DirBackupTemp}/${PrefixBackup}.APP.`_DataHora`.tar.gz"
   sudo test ! -d $DirBackupTemp && sudo mkdir -p $DirBackupTemp
   echo "--- Files Backup ---"
   sudo tar czf $Destino $Origem 2>/dev/null || local RC=$?
   if [ $RC -eq 0 ]; then
      export PathBackupAPP="$Destino"
      echo "PathBackupAPP=$Destino"
      echo "--- MD5 (hash) ---"
      sudo md5sum "$Destino"
      echo "--- Status ---"
      sudo stat "$Destino"
   fi
   return $RC
}

# Dumping database (MySQL) 
_BackupBancoDados(){
   local RC=0
   local Destino="${DirBackupTemp}/${PrefixBackup}.BD.`_DataHora`.sql"
   { sudo mysqldump --host="${BDHost}" --databases "${BDDataBase}" --user="${BDUser}" --password="${BDPassword}" --result-file=$Destino && \
   sudo gzip -9 $Destino; } || local RC=$?
   if [ $RC -eq 0 ]; then
      export PathBackupBD="${Destino}.gz"
      echo "ArquivoBackupBD=${Destino}.gz"
      echo "--- MD5 (hash) ---"
      sudo md5sum "$PathBackupBD"
      echo "--- Status ---"
      sudo stat "$PathBackupBD"
   fi
   return $RC
}

# Packaging both GZ's 
_ArchiveAppBd(){
   local RC=0
   local OrigemAPP="$PathBackupAPP"
   local OrigemBD="$PathBackupBD"
   local DestinoAppBd="${DirBackupTemp}/${PrefixBackup}.AppBd.`_DataHora`.tar.gz"
   sudo tar -czvf $DestinoAppBd $OrigemAPP $OrigemBD 2>/dev/null || local RC=$?
   sudo chown --recursive --verbose $UserSCP:$UserSCP $DestinoAppBd
   if [ $RC -eq 0 ]; then
      export PathBackupAppBd="$DestinoAppBd"
      echo "ArquivoBackupAppBd=$DestinoAppBd"
      echo "--- MD5 (hash) ---"
      sudo md5sum "$DestinoAppBd"
      echo "--- Status ---"
      sudo stat "$DestinoAppBd"
   fi
   return $RC
}

# Leaving temporary files 
_LimpezaArquivosDump(){
   local RC=0
   echo "DirBackupTemp $DirBackupTemp"
   echo "PathBackupAppBd $PathBackupAppBd"
   sudo rm -rfv `find "$DirBackupTemp" -not -name "*.AppBd.*" -type f` || local RC=$?
   return $RC
}
 
##--- Begin code ---##

# Start RC
RC=0
{
echo "#---- Inicio - Geracao de tarball (APP+BD) ----#"
_Print INFO "Ativando flag de backup"

# Enable maintenance flag 
_FlagPHPBackup on || RC=$?
if [ $RC -eq 0 ]; then
   _Print INFO "Realizando backup dos arquivos de sistema"
   
   # Backup app files 
   _BackupSistemaArquivos || RC=$?
   if [ $RC -eq 0 ]; then
      _Print INFO "Extraindo dump do database"

      # Database backup
      _BackupBancoDados || RC=$?
      if [ $RC -eq 0 ]; then
         _Print INFO "Arquivando arquivos e dump em tarball"
	 
	 # Main tarball 
         _ArchiveAppBd || RC=$?
         if [ $RC -eq 0 ]; then
            _Print INFO "Desativando flag de backup"

	    # Disable maintenance flag 
            _FlagPHPBackup off || RC=$?
            if [ $RC -eq 0 ]; then

	       # Statuses for debugging 
               _Print SUCESS "Flag de backup desativada"
               _Print SUCESS "Backup APP + BD realizado com sucesso"
               _Print INFO "Arquivo final p/ sincronizacao remota \n\n\t>>>>>@${PathBackupAppBd}@<<<<"
               _Print INFO "Removendo tarball dos arquivos e dump"
               _LimpezaArquivosDump || RC=$?
               if [ $RC -eq 0 ]; then
                  _Print SUCESS "Tarball dos arquivos e dump/db removidos com sucesso"
               else
                  _Print WARN "Tarball dos arquivos e dump/db nao removidos"
               fi
            else
               _Print ERRO "Erro desativando flag de backup"
            fi
         else
            _Print  ERRO "Erro no archive app+bd"
            _Print ERRO "Erro na execucao do backup APP+BD"
         fi
      else
         _Print ERRO "Erro na extracao do dump"
      fi
   else
      _Print ERRO "Erro na extracao dos arquivos fs"
   fi
elif [ $RC -eq  ]; then
   _Print ERRO "Erro ativando a flag de backup ****"
fi
echo "#---- Fim - Geracao de tarball (APP+BD) ----#"

# Output append log 
} | sudo tee --append $ArquivoLog | sudo mail -s "Backup MediaWiki - Geracao de Tarball (APP+BD)" "$MailList"
 
echo "Para maiores detalhes acesse: @${ArquivoLog}"
 
exit $RC

##--- End code ---##
