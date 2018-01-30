#!/bin/bash
#set -x
 
# Titulo        : "backupMediaWIki.dump.sh"
# Descricao     : Este script gera arquivo unico (app+bd) da wiki p/ backup remoto.
# Autor         : Aecio Junior <aeciojr@gmail.com>
# Data          : 28 de Agosto de 2015.
# Versao        : 1.1 - Adicionado comentarios; 
# Usage         : ./backupMediaWIki.dump.sh
 
##---- Variaveis de configuracao ----##

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

##--- Variaveis de script ---##

Basename="`basename $0`"
ArquivoLog="${DirLog}/${Basename}.log"
PrefixBackup="BkpMediaWiki"

##------ Funcoes ------------##

# Funcao p/ obter data e hora em formato padrao
_DataHora(){ date "+%Y%m%d_%H%M%S_$RANDOM"; }

# Imprimir data e hora
_DataHoraPrint(){ date "+%Y/%m/%d %H:%M:%S"; }

# Funcao para emitir output log
_Print(){
   local Flag="$( echo $1 | tr [:lower:] [:upper:])"
   echo -e "\n`_DataHoraPrint` [ $Flag ] $2 \n"
}

# Funcao para ativar/desativar flag de manutencao da Wiki
_FlagPHPBackup(){
   # Uso _FlagPHPBackup ON|OFF
   local RC=0
   if [ $# -eq 1 ]
   then
      local Op=$( echo $1 | tr [:lower:] [:upper:] )
      if [ "${Op}x" == "OFFx" ]; then
         { sudo sed -i '/$wgReadOnly/s/^/#/' $ArquivoConfiguracoes && echo "FlagBkp[ wgReadOnly ] DESATIVADA no $ArquivoConfiguracoes"; } || local RC=$?
      elif [ "${Op}x" == "ONx" ]; then
         { sudo sed -i 's/^#$wgReadOnly/$wgReadOnly/' $ArquivoConfiguracoes && echo "FlagBkp [ wgReadOnly ] ATIVADA no $ArquivoConfiguracoes"; } || local RC=$?
      else
         echo "Forneca argumento ON|OFF"
         local RC=2
      fi
   else
      echo "Forneca argumento ON|OFF"
      local RC=3
   fi
   return $RC
}

# Geracal de tarball com arquivos da aplicacao
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

# Dump do banco de dados
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

# Criacao de tarball unico
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

# Remocao de arquivos desecessarios
_LimpezaArquivosDump(){
   local RC=0
   echo "DirBackupTemp $DirBackupTemp"
   echo "PathBackupAppBd $PathBackupAppBd"
   sudo rm -rfv `find "$DirBackupTemp" -not -name "*.AppBd.*" -type f` || local RC=$?
   return $RC
}
 
##--- Incio do script ---##

# Inicia RC
RC=0
{
echo "#---- Inicio - Geracao de tarball (APP+BD) ----#"
_Print INFO "Ativando flag de backup"

# Ativa a flag de manutencao ou muda o RC em caso de ERRO
_FlagPHPBackup on || RC=$?
if [ $RC -eq 0 ]; then
   _Print INFO "Realizando backup dos arquivos de sistema"
   
   # Realiza o backup do sistema de arquivos ou muda o RC em caso de ERRO
   _BackupSistemaArquivos || RC=$?
   if [ $RC -eq 0 ]; then
      _Print INFO "Extraindo dump do database"

      # Realiza o backup do banco de dados ou muda o RC em caso de ERRO
      _BackupBancoDados || RC=$?
      if [ $RC -eq 0 ]; then
         _Print INFO "Arquivando arquivos e dump em tarball"
	 
	 # Cria tarball unico
         _ArchiveAppBd || RC=$?
         if [ $RC -eq 0 ]; then
            _Print INFO "Desativando flag de backup"

	    # Desativa a flag de manuntencao
            _FlagPHPBackup off || RC=$?
            if [ $RC -eq 0 ]; then

	       # Emite status p/ debugging
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

# Realiza o append da output em arquivo de log
} | sudo tee --append $ArquivoLog | sudo mail -s "Backup MediaWiki - Geracao de Tarball (APP+BD)" "$MailList"
 
echo "Para maiores detalhes acesse: @${ArquivoLog}"
 
exit $RC

##--- Fim do script ---##
