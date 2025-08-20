#!/bin/bash

# YendorCats Monitoring Script
echo "📊 YendorCats System Status"
echo "=========================="

echo -e "\n🐳 Docker Containers:"
docker-compose ps

echo -e "\n💾 Disk Usage:"
df -h /

echo -e "\n🔧 Memory Usage:"
free -h

echo -e "\n📊 CPU Usage:"
top -bn1 | grep "Cpu(s)" | awk '{print $2 $3 $4}'

echo -e "\n🌐 Network Connections:"
netstat -tuln | grep -E ':(80|443|8080|8443|5000)'

echo -e "\n📋 Recent Application Logs:"
docker-compose logs --tail=5 2>/dev/null || echo "No containers running"

echo -e "\n🔍 Container Health:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" 2>/dev/null || echo "No containers running"
