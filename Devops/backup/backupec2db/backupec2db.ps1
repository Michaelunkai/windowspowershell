<#
.SYNOPSIS
    backupec2db
#>
New-Item -ItemType Directory -Force -Path C:\users\micha\downloads\ec2
    scp -i "F:\\backup\windowsapps\Credentials\AWS\key.pem" ubuntu@54.173.176.93:/home/ubuntu/study_tracker/study_tracker.db C:\users\micha\downloads\ec2
    scp -i "F:\\backup\windowsapps\Credentials\AWS\key.pem" ubuntu@54.173.176.93:/home/ubuntu/wishlist/wishlist.db C:\users\micha\downloads\ec2
    scp -i "F:\\backup\windowsapps\Credentials\AWS\key.pem" ubuntu@54.173.176.93:/home/ubuntu/stickynotes/instance/notes.db C:\users\micha\downloads\ec2
    cp F:\\study\docker\dockerfiles\buildthispath C:\users\micha\Downloads\ec2\Dockerfile
    wsl -d ubuntu -e sh -c 'cd /mnt/f/Users/micha/Downloads/ec2 && docker build -t michadockermisha/backup:ec2db . && docker push michadockermisha/backup:ec2db'
    Remove-Item -Recurse -Force C:\users\micha\downloads\ec2
