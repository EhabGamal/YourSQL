#!/usr/bin/bash
PS3="Select option : "
dbDir="/usr/local/ehabDBMS"
dbConfig=$dbDir"/.config"
dbPasswd=$dbConfig"/passwd"
PS3="Enter your choice: ";
COLUMNS=1
banner() {
    msg="# $* #"
    edge=$(echo "$msg" | sed 's/./=/g')
    echo "$edge"
    echo "$msg"
    echo "$edge"
}
function initDBMS {
    if [[ ! -e $dbDir  ]]; then
        sudo mkdir -p $dbDir;
        sudo mkdir -p $dbConfig;
        sudo touch $dbPasswd;
        sudo chmod 777 $dbDir;
        sudo chmod 777 $dbConfig;
        sudo chmod 777 $dbPasswd;
    fi
    cd "$dbDir";
    mainMenu
}
function createDatabase {
    clear;
    banner "Create new database"
    echo -n "Enter Database Name: "
    read dbName
    local dbPath="$dbDir"/"$dbName"
    local dbConfigPath="$dbConfig"/"$dbName"
    if [ ! -d "$dbPath"  ]; then
        sudo mkdir "$dbPath";
        sudo touch "$dbConfigPath";
        sudo chmod 777 "$dbPath";
        sudo chmod 666 "$dbConfigPath";
        echo -e "$dbName database created successfully!\npress any key to continue";
        read
    else
        echo "Database already existed!";
        echo -en "\033[33;31mDo you want to overwrite it? [Y/N]:\e[0m ";
        read input
        if [ $input = Y -o $input = y ]; then
            sudo rmdir "$dbPath";
            echo "Old database removed successfully!";
            sudo mkdir "$dbPath";
            sudo chmod 777 "$dbPath";
            echo -e "$dbName database created successfully!\npress any key to continue";
            read
        fi
    fi
}
function showDatabases {
    ls | awk 'BEGIN{FS=" "} { print "- "$1 }';
}
function descDatabases {
  clear;
  banner "Available Databases";
  showDatabases;
  echo "press any key to continue.."
  read
}
function selectDatabase {
    select="Y"
    while [ $select = "Y" -o $select = "y" ]; do
      clear;
      banner "Select Database";
      showDatabases;
      echo -n "Enter database name: "
      read dbName
      local dbPath="$dbDir"/"$dbName"
      if [ ! -d "$dbPath"  ]; then
          echo -en "Database not existed!\nSelect another database? [Y/N]: "
          read select;
      else
          cd "$dbPath";
          databaseMenu;
      fi
    done
}
function dropDatabase {
    drop="Y";
    while [ $drop = "Y" -o $drop = "y" ]; do
      clear;
      banner "Select Database to Drop";
      showDatabases;
      echo -n "Database name: "
      read dbName;
      if [ -d $dbName ]; then
        echo "You are going to drop $dbName permanently!";
        echo -n "Are you sure? [Y/N]: "
        read input
        if [ $input = "Y" -o $input = "y" ]; then
          sudo rm -r $dbName;
          sudo rm "$dbConfig/$dbName";
          echo "Database removed successfully!"
        fi
      else
        echo "$dbName database is not existed!";
      fi
      echo -n "Drop another database? [Y/N]: "
      read drop;
    done
}
function addPrimaryKey {
  clear;
  pkinput="Y"
  banner "Adding primary key to $dbName.$tableName";
  echo $rowHeader | awk 'BEGIN{ RS=";" ; FS="." }{ print "- " $1 }'
  while [[ $pkinput == "Y" || $pkinput == "y" ]]; do
    echo -n "Enter column name: ";
    read PKName;
    typeset -i colIndex=$(echo $rowHeader | awk -v col="$PKName" 'BEGIN{RS=";";FS=".";i=0} $1==col{ i=NR }; END{print i}')
    if [  $colIndex -ne 0 ]; then
      echo $tableName:$PKName:$colIndex >> $dbConfig/$dbName;
      echo -e "$PKName Primary Key constraint addedd successfully!\nPress any key to continue.."
      read;
      break;
    else
      echo -en "$1 column is not existed!\nTry again? [Y/N]: "
      read pkinput;
    fi
  done
}
function isPrimaryKey {
  PKName=$(echo $1 | awk 'BEGIN{FS="."}; NR==1{print $1}')
  TableConfig=$(awk -v tbname="$tableName" 'BEGIN{FS=":";TF="0";}; $1==tbname{print $0; TF="1";}; END{if(TF=="0") print "0";}' $dbConfig/$dbName)
  if [[ $TableConfig != "0" ]]; then
    PKConfig=$(echo "$TableConfig" | awk -v col="$PKName" 'BEGIN{FS=":";PF="0";}; $2==col{PF="1"; print $3}; END{if(PF=="0") print "0"};')
    echo $PKConfig;
  else
    echo "0"
  fi
}
function checkPrimaryKey {
  PKFound="0";
  PKColumn=($(awk -v pkindex="$PKIndex" 'BEGIN{FS=";"}; {print $pkindex};' $tableName))
  for PK in "${PKColumn[@]}"; do
    if [[ $PK == $input ]]; then
      PKFound="1";
      break;
    fi
  done
  echo $PKFound;
}
function checkPrimaryKey2 {
  PKFound="0";
  PKColumn=($(awk -v pkindex="$1" 'BEGIN{FS=";"}; {print $pkindex};' $tableName))
  for PK in "${PKColumn[@]}"; do
    if [[ $PK == $2 ]]; then
      PKFound="1";
      break;
    fi
  done
  echo $PKFound;
}
function createColumns {
  rowHeader=""
  for (( i = 0; i < $1; i++ )); do
    newColumn=""
    echo -n "Column $((i+1)) name: "
    read newColumn
    if [[ $rowHeader == *$newColumn* ]]; then
      echo "column name \"$newColumn\" alreadey existed!";
      ((i--));
      continue
    fi
    echo -n "[int OR char]: "
    read colType
    if [[ $colType != "int" && $colType != "char" ]]; then
      echo "Datatype \"$colType\" is not supported!";
      ((i--));
      continue
    fi
    newColumn="$newColumn.$colType"
    rowHeader="$rowHeader$newColumn"";"
  done
  rowHeader="${rowHeader::-1}";
  echo "$rowHeader" >> "$tablePath";
  echo -en "Table created successfully!\nWant to add Primary Key constraint? [Y/N] "
  read input
  if [[ $input == "Y" || $input == "y" ]]; then
    addPrimaryKey;
  fi
}
function createTable {
    clear;
    banner "$dbName : Create New Table"
    echo -n "Enter table name: "
    read tableName;
    typeset -i colsNumber=-1;
    tablePath="$dbPath"/"$tableName";
    if [ ! -f "$tablePath"  ]; then
        echo -n "Number of columns: "
        read colsNumber;
    else
        echo -n "Table already existed! Overwrite it? [Y/N]: "
        read input;
        if [ $input = Y -o $input = y ]; then
            sudo rm "$tablePath"
            echo -n "Number of columns: "
            read colsNumber;
        fi
    fi
    until [[ $colsNumber -gt 0 ]]; do
      if [[ $colsNumber -eq -1 ]]; then
        clear; break 2;
      else
        echo -en "Illegal number of columns! [-1 to Cancel]\n"
        echo -n "Number of columns: "
        read colsNumber
      fi
    done
    sudo touch "$tablePath"
    sudo chmod 666 "$tablePath"
    createColumns $colsNumber;
}
function insertIntoTable {
  insert="Y"
  while [ $insert = "Y" -o $insert = "y" ]; do
    clear;
    newRecord=""
    banner "Inserting new record in $tableName table"
    tableHeader=$(head -1 "$tableName");
    columnsList=$(echo  "$tableHeader" | awk 'BEGIN{RS=";"}; {print}')
    for col in $columnsList
    do
      colType=$(echo "$col" | awk 'BEGIN{FS="."}; NR==1{print $2}')
      echo -n "$col: "
      read input
      if [[ $colType == "int" ]]; then
        while ! [[ $input =~ ^[0-9] ]]; do
          echo "Invalid input datatype! enter $colType value";
          echo -n "$col: "
          read input
        done
      fi
      PKIndex=$(isPrimaryKey $col);
      if [[ $PKIndex != "0" ]]; then
        ChkPK=$(checkPrimaryKey);
        while [[ $ChkPK == "1" ]]; do
          echo -en "Primary key value already existed!\n$col: "
          read input
          ChkPK=$(checkPrimaryKey);
        done
      fi
      newRecord="$newRecord$input;"
    done
    echo "${newRecord::-1}" >> "$tablePath";
    echo -en "Record added successfully!\nInsert another record? [Y/N]: ";
    read insert;
  done
}
function columnExisted {
  echo $tableHeader | awk -v col="$1" 'BEGIN{RS=";";FS=".";i=0} $1==col{ i=NR }; END{print i}'
}
function viewTableData {
  clear;
  banner "SELECT $1 FROM $tableName"
  if [ $1 = "ALL" -o $1 = "all" ]; then
    head -1 $tableName | awk 'BEGIN{FS=".";RS=";"; ORS="\t"}; {print $1}'
    echo -e "\n"
    awk 'BEGIN{FS=";"; OFS="\t"}; NR>1{$1=$1;print $0}' "$tableName"
  else
    typeset -i colIndex=$(columnExisted $1)
    if [  $colIndex -ne 0 ]; then
      awk -v i="$colIndex" 'BEGIN{FS=";"}; {print $i}' "$tableName"
    else
      echo "$1 is not existed!"
    fi
  fi
  echo -n "press enter to continue.."
  read
}
function listTableColumns {
  tableHeader=$(head -1 "$tableName");
  echo $tableHeader | awk 'BEGIN{ RS=";" ; FS="." }{ print "- "$1 }'
}
function deleteRows {
  clear;
  banner "Select column to delete with it";
  tableHeader=$(head -1 "$tableName");
  echo $tableHeader | awk 'BEGIN{ RS=";" ; FS="." }{ print "- " $1 }'
  echo -n "Enter column name: "
  read input
  typeset -i colIndex=$(columnExisted $input)
  if [  $colIndex -ne 0 ]; then
    echo -n "DELETE FROM $tableName WHERE $input = "
    read where
    echo "$tableHeader" > "$tableName"."temp"
    awk -v i="$colIndex" -v w="$where" 'BEGIN{FS=";"}; NR>1{if($i!=w) print $0}' "$tableName" >> "$tableName"."temp"
    sudo mv -f "$tableName"."temp" "$tableName"
    echo -en "Records deleted successfully!\npress enter to continue.."
    read
  else
    echo "$1 is not existed!"
  fi
}
function updateRows {
  clear;
  banner "Select column to update with it";
  tableHeader=$(head -1 "$tableName");
  echo $tableHeader | awk 'BEGIN{ RS=";" ; FS="." }{ print "- " $1 }'
  echo -n "Enter column name: "
  read input
  typeset -i colIndex=$(columnExisted $input)
  if [  $colIndex -ne 0 ]; then
    echo -n "UPDATE $tableName WHERE $input = "
    read where
    echo -n "SET $input NEW VALUE = "
    read newval
    columnType=$(echo $tableHeader | awk -v n="$colIndex" 'BEGIN{FS=";"}; { split($n,arr,"."); print arr[2]}')
    columnName=$(echo $tableHeader | awk -v n="$colIndex" 'BEGIN{FS=";"}; { print $n}')
    if [[ $columnType == "int" ]]; then
      while ! [[ $newval =~ ^[0-9] ]]; do
        echo "Invalid input datatype! enter $columnType value";
        echo -n "SET $input NEW VALUE = "
        read newval
      done
    fi
    if [[ $(isPrimaryKey "$columnName") == "1" ]]; then
      ChkPK=$(checkPrimaryKey2 $colIndex $newval)
      while [[ $ChkPK == "1" ]]; do
        echo "Primary Key value already existed!";
        echo -n "SET PRIMARY KEY NEW VALUE = "
        read newval;
        ChkPK=$(checkPrimaryKey2 $colIndex $newval)
      done
    fi
    echo "$tableHeader" > "$tableName"."temp"
    awk -v i="$colIndex" -v w="$where" -v n="$newval" '
    BEGIN{FS=";"};
    NR>1{
      if($i==w){
        gsub(w,n,$i);
        OFS=";";
      }
      print $0;
    }' "$tableName" >> "$tableName"."temp"
    sudo mv -f "$tableName"."temp" "$tableName"
    echo -en "Records updated successfully!\npress enter to continue.."
    read
  else
    echo "$1 is not existed!"
  fi
}
function updateRows2 {
  clear;
  banner "Select column to update";
  tableHeader=$(head -1 "$tableName");
  echo $tableHeader | awk 'BEGIN{ RS=";" ; FS="." }{ print "- " $1 }'
  echo -n "Enter column name: "
  read input
  typeset -i colIndex=$(columnExisted $input)
  if [  $colIndex -ne 0 ]; then
    echo -n "UPDATE $tableName WHERE $input = "
    read where
    echo -n "SET $input NEW VALUE = "
    read newval
    columnType=$(echo $tableHeader | awk -v n="$colIndex" 'BEGIN{FS=";"}; { split($n,arr,"."); print arr[2]}')
    columnName=$(echo $tableHeader | awk -v n="$colIndex" 'BEGIN{FS=";"}; { split($n,arr,"."); print arr[1]}')
    if [[ $columnType == "int" ]]; then
      while ! [[ $newval =~ ^[0-9] ]]; do
        echo "Invalid input datatype! enter $columnType value";
        echo -n "SET $input NEW VALUE = "
        read newval
      done
    fi
    echo "$tableHeader" > "$tableName"."temp"
    awk -v i="$colIndex" -v w="$where" -v n="$newval" '
    BEGIN{FS=";"};
    NR>1{
      if($i==w){
        gsub(w,n,$i);
        OFS=";";
      }
      print $0;
    }' "$tableName" >> "$tableName"."temp"
    sudo mv -f "$tableName"."temp" "$tableName"
    echo -en "Records updated successfully!\npress enter to continue.."
    read
  else
    echo "$1 is not existed!"
  fi
}
function selectFromTable {
  clear;
  typeset -i colIndex=0;
  banner "Select column to view";
  listTableColumns;
  echo "- ALL"
  echo -n "Enter column name: "
  read input
  viewTableData $input
}
function selectTable {
  selct="Y"
  while [ $selct = "Y" -o $selct = "y" ]; do
    clear;
    banner "Select table to continue";
    showTables;
    echo -n "Enter table name: "
    read tableName;
    tablePath="$dbDir"/"$dbName"/"$tableName";
    if [ -f $tablePath ]; then
      if [ $1 = "select" ]; then
        selectFromTable;
      elif [ $1 = "insert" ]; then
        insertIntoTable;
      elif [ $1 = "update" ]; then
        updateRows;
      elif [ $1 = "delete" ]; then
        deleteRows;
      fi
    else
      echo "$tableName table is not existed!"
      echo -n "Select another table? [Y/N]: "
      read selct;
    fi
  done
}
function dropTable {
  drop="Y";
  while [ $drop = "Y" -o $drop = "y" ]; do
    clear;
    banner "Select Table to Drop";
    showTables;
    echo -n "Table name: "
    read tableName;
    if [ -f $tableName ]; then
      echo "You are going to drop $tableName permanently!";
      echo -n "Are you sure? [Y/N]: "
      read input
      if [ $input = "Y" -o $input = "y" ]; then
        sudo rm $tableName;
        echo "Table removed successfully!"
        read
      fi
    else
      echo "$tableName table is not existed!";
    fi
    echo -n "Drop another table? [Y/N]: "
    read drop;
  done
}
function showTables {
  ls | awk 'BEGIN{FS=" "} { print "- "$1 }';
}
function descDatabase {
  clear;
  banner "$dbName Tables";
  showTables;
  echo "press any key to continue.."
  read
}
function databaseMenu {
    clear;
    while true
    do
      banner "Current DB: $dbName";
      dbMenuOpts=("DB Desc" "Create table" "Insert" "Select" "Update" "Delete" "Drop" "Change DB" "Home")
      select opt in "${dbMenuOpts[@]}"
      do
        case $REPLY in
          1) descDatabase; clear; continue 2 ;;
          2) createTable; clear; continue 2 ;;
          3) selectTable "insert"; clear; continue 2 ;;
          4) selectTable "select"; clear; continue 2 ;;
          5) selectTable "update"; clear; continue 2 ;;
          6) selectTable "delete"; clear; continue 2 ;;
          7) dropTable; clear; continue 2 ;;
          8) cd "$dbDir"; break 2 ;;
          9) cd "$dbDir"; break 3 ;;
          *) echo "Not a valid option!";;
        esac
      done
    done
}
function mainMenu {
    banner "Welcome to YourSQL not MySQL ;D";
    while true
    do
      banner "YourSQL DBMS MainMenu";
      mainMenuOpts=("Select Database" "Create Database" "Show Databases" "Drop Database" "Quit")
      select opt in "${mainMenuOpts[@]}"
      do
        case $REPLY in
          1) selectDatabase; clear; break;;
          2) createDatabase; clear; break;;
          3) descDatabases; clear; break;;
          4) dropDatabase; clear; break;;
          5) banner "Thanks for using YourSQL"; break 2;;
          *) echo "Not a valid choice!";;
        esac
      done
    done
}
clear
initDBMS
