#!/bin/bash
sudo apt update -y && sudo apt upgrade -y && sudo apt autoremove -y && cd /tmp && wget https://download.java.net/java/GA/jdk23/3c5b90190c68498b986a97f276efd28a/37/GPL/openjdk-23_linux-x64_bin.tar.gz && sudo tar -xzf openjdk-23_linux-x64_bin.tar.gz -C /usr/local/ && sudo update-alternatives --install /usr/bin/java java /usr/local/jdk-23/bin/java 1 && sudo update-alternatives --install /usr/bin/javac javac /usr/local/jdk-23/bin/javac 1 && sudo update-alternatives --set java /usr/local/jdk-23/bin/java && sudo update-alternatives --set javac /usr/local/jdk-23/bin/javac && java -version && sudo useradd -m -U -d /opt/tomcat -s /bin/false tomcat 2>/dev/null || true && cd /tmp && wget https://archive.apache.org/dist/tomcat/tomcat-10/v10.1.33/bin/apache-tomcat-10.1.33.tar.gz && sudo mkdir -p /opt/tomcat && sudo tar xzf apache-tomcat-10.1.33.tar.gz -C /opt/tomcat --strip-components=1 && sudo chown -R tomcat:tomcat /opt/tomcat/ && sudo chmod -R u+x /opt/tomcat/bin && echo '[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
User=tomcat
Group=tomcat
Environment="JAVA_HOME=/usr/local/jdk-23"
Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"
Environment="CATALINA_HOME=/opt/tomcat"
Environment="CATALINA_BASE=/opt/tomcat"
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target' | sudo tee /etc/systemd/system/tomcat.service && sudo systemctl daemon-reload && sudo systemctl start tomcat && sudo systemctl enable tomcat && echo "================================" && echo "Java Version:" && java -version && echo "================================" && echo "Tomcat Version:" && /opt/tomcat/bin/version.sh && echo "================================" && echo "Tomcat Status:" && sudo systemctl status tomcat --no-pager && echo "================================"
