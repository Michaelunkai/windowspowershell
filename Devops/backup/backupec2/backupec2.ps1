<#
.SYNOPSIS
    backupec2
#>
New-Item -ItemType Directory -Force -Path C:\users\micha\downloads\ec2\apps, C:\users\micha\downloads\ec2\services
    scp -i "F:\\backup\windowsapps\Credentials\AWS\key.pem" -r ubuntu@54.173.176.93:/home/ubuntu/* C:\users\micha\downloads\ec2\apps
    scp -i "F:\\backup\windowsapps\Credentials\AWS\key.pem" ubuntu@54.173.176.93:/etc/systemd/system/wishlist.service C:\users\micha\downloads\ec2\services
    scp -i "F:\\backup\windowsapps\Credentials\AWS\key.pem" ubuntu@54.173.176.93:/etc/systemd/system/stickynotes.service C:\users\micha\downloads\ec2\services
    scp -i "F:\\backup\windowsapps\Credentials\AWS\key.pem" ubuntu@54.173.176.93:/etc/systemd/system/studytracker.service C:\users\micha\downloads\ec2\services
    scp -i "F:\\backup\windowsapps\Credentials\AWS\key.pem" ubuntu@54.173.176.93:/etc/systemd/system/speach2text.service C:\users\micha\downloads\ec2\services
    scp -i "F:\\backup\windowsapps\Credentials\AWS\key.pem" ubuntu@54.173.176.93:/etc/systemd/system/flask_file_explorer.service C:\users\micha\downloads\ec2\services
    wsl -d ubuntu -e sh -c 'cd /mnt/f/Users/micha/Downloads/ec2 && docker build -t michadockermisha/backup:ec2 . && docker push michadockermisha/backup:ec2'
