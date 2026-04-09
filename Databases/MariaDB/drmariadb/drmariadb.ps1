<#
.SYNOPSIS
    drmariadb
#>
docker run -v "C:/:/c/" -it -d --name mariadb -e MYSQL_ROOT_PASSWORD=123456 -p 3307:3307 mariadb:latest;
    Start-Sleep -Seconds 30;
    docker exec -it mariadb mariadb -u root -p
