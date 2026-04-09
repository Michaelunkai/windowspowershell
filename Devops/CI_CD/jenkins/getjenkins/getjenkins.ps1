<#
.SYNOPSIS
    getjenkins
#>
docker run -d -p 8080:8080 -p 50000:50000 -v jenkins_home:/var/jenkins_home --name jenkins jenkins/jenkins:lts;
    Start-Sleep -Seconds 30;
    docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
