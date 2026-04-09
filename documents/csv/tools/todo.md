# TODO - CSV Tools Setup

## Next Steps (Execute in Order)

### 1. csview
```powershell
mkdir -p "F:\study\documents\csv\tools\csview"
```
Create file: `F:\study\documents\csv\tools\csview\liner to setup and run csview in ubuntu.txt`
Content: `sudo apt update && sudo apt install -y cargo && cargo install csview && echo 'export PATH=$PATH:$HOME/.cargo/bin' >> ~/.bashrc && source ~/.bashrc && csview --version && echo "csview installed! Try: csview file.csv (fast CSV viewer with column selection)"`

### 2. qsv
```powershell
mkdir -p "F:\study\documents\csv\tools\qsv"
```
Create file: `F:\study\documents\csv\tools\qsv\liner to setup and run qsv in ubuntu.txt`
Content: `cd /tmp && wget https://github.com/jqnatividad/qsv/releases/latest/download/qsv-0.134.0-x86_64-unknown-linux-gnu.zip && sudo apt install -y unzip && unzip qsv-0.134.0-x86_64-unknown-linux-gnu.zip && sudo mv qsv* /usr/local/bin/ && qsv --version && echo "qsv installed! Try: qsv stats file.csv, qsv select name,age file.csv, qsv search -s name 'John' file.csv"`

### 3. gocsv
```powershell
mkdir -p "F:\study\documents\csv\tools\gocsv"
```
Create file: `F:\study\documents\csv\tools\gocsv\liner to setup and run gocsv in ubuntu.txt`
Content: `cd /tmp && wget https://github.com/DataFoxCo/gocsv/releases/latest/download/gocsv-linux-amd64 && sudo mv gocsv-linux-amd64 /usr/local/bin/gocsv && sudo chmod +x /usr/local/bin/gocsv && gocsv version && echo "gocsv installed! Try: gocsv select name,age file.csv, gocsv filter 'age > 25' file.csv, gocsv join --left file1.csv file2.csv"`

### 4. tabview
```powershell
mkdir -p "F:\study\documents\csv\tools\tabview"
```
Create file: `F:\study\documents\csv\tools\tabview\liner to setup and run tabview in ubuntu.txt`
Content: `sudo apt update && sudo apt install -y python3 python3-pip && pip3 install tabview && echo 'export PATH=$PATH:$HOME/.local/bin' >> ~/.bashrc && source ~/.bashrc && tabview --version && echo "tabview installed! Try: tabview file.csv (terminal spreadsheet - arrow keys to navigate, q to quit)"`

### 5. csvtk
```powershell
mkdir -p "F:\study\documents\csv\tools\csvtk"
```
Create file: `F:\study\documents\csv\tools\csvtk\liner to setup and run csvtk in ubuntu.txt`
Content: `cd /tmp && wget https://github.com/shenwei356/csvtk/releases/latest/download/csvtk_linux_amd64.tar.gz && tar xzf csvtk_linux_amd64.tar.gz && sudo mv csvtk /usr/local/bin/ && csvtk version && echo "csvtk installed! Try: csvtk stats file.csv, csvtk cut -f name,age file.csv, csvtk grep -f name -p 'John' file.csv, csvtk freq -f country file.csv"`

### 6. trdsql
```powershell
mkdir -p "F:\study\documents\csv\tools\trdsql"
```
Create file: `F:\study\documents\csv\tools\trdsql\liner to setup and run trdsql in ubuntu.txt`
Content: `cd /tmp && wget https://github.com/noborus/trdsql/releases/latest/download/trdsql_linux_amd64.zip && sudo apt install -y unzip && unzip trdsql_linux_amd64.zip && sudo mv trdsql /usr/local/bin/ && trdsql -version && echo "trdsql installed! Try: trdsql 'SELECT * FROM file.csv WHERE age > 25', trdsql 'SELECT name, AVG(salary) FROM file.csv GROUP BY name'"`

### 7. octosql
```powershell
mkdir -p "F:\study\documents\csv\tools\octosql"
```
Create file: `F:\study\documents\csv\tools\octosql\liner to setup and run octosql in ubuntu.txt`
Content: `cd /tmp && wget https://github.com/cube2222/octosql/releases/latest/download/octosql_linux_amd64 && sudo mv octosql_linux_amd64 /usr/local/bin/octosql && sudo chmod +x /usr/local/bin/octosql && octosql --version && echo "octosql installed! Try: octosql 'SELECT * FROM file.csv WHERE age > 25'"`

### 8. textql
```powershell
mkdir -p "F:\study\documents\csv\tools\textql"
```
Create file: `F:\study\documents\csv\tools\textql\liner to setup and run textql in ubuntu.txt`
Content: `cd /tmp && wget https://github.com/dinedal/textql/releases/latest/download/textql_linux_amd64 && sudo mv textql_linux_amd64 /usr/local/bin/textql && sudo chmod +x /usr/local/bin/textql && textql -version && echo "textql installed! Try: textql -sql 'SELECT * FROM file.csv WHERE age > 25' file.csv"`

### 9. csvdiff
```powershell
mkdir -p "F:\study\documents\csv\tools\csvdiff"
```
Create file: `F:\study\documents\csv\tools\csvdiff\liner to setup and run csvdiff in ubuntu.txt`
Content: `sudo apt update && sudo apt install -y python3 python3-pip && pip3 install csvdiff && echo 'export PATH=$PATH:$HOME/.local/bin' >> ~/.bashrc && source ~/.bashrc && csvdiff --version && echo "csvdiff installed! Try: csvdiff file1.csv file2.csv --primary-key id"`

## Mark Complete After Each Step
Update todo list using TodoWrite tool after completing each folder/file creation.
