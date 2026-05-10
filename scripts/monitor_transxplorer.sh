#!/bin/bash

clear
echo "=========================================="
echo "TransXplorer Live Monitor"
echo "=========================================="
echo "Press Ctrl+C to exit"
echo ""

while true; do
    clear
    echo "=========================================="
    echo "TransXplorer Status - $(date)"
    echo "=========================================="
    echo ""
    
    # Container health
    echo "📦 Container Status:"
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep transxplorer
    echo ""
    
    # Resource usage
    echo "💾 Resource Usage:"
    docker stats transxplorer_app --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
    echo ""
    
    # Active connections
    HTTPS_CONN=$(docker exec transxplorer_nginx sh -c "netstat -an 2>/dev/null | grep :443 | grep ESTABLISHED | wc -l" 2>/dev/null || echo "0")
    HTTP_CONN=$(docker exec transxplorer_nginx sh -c "netstat -an 2>/dev/null | grep :80 | grep ESTABLISHED | wc -l" 2>/dev/null || echo "0")
    SHINY_SESSIONS=$(docker exec transxplorer_app sh -c "ps aux 2>/dev/null | grep -c '[R]script.*shiny'" 2>/dev/null || echo "0")
    
    echo "👥 Active Users:"
    echo "   HTTPS Connections: $HTTPS_CONN"
    echo "   HTTP Connections: $HTTP_CONN"
    echo "   Active Shiny Sessions: $SHINY_SESSIONS"
    echo ""
    
    # Top IPs
    echo "🌐 Top Connected IPs:"
    docker exec transxplorer_nginx sh -c "netstat -an 2>/dev/null | grep :443 | grep ESTABLISHED | awk '{print \$5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -5" 2>/dev/null || echo "   No connections"
    echo ""
    
    # System resources
    echo "💻 Server Resources:"
    free -h | grep "Mem:" | awk '{print "   Memory: "$3" used / "$2" total ("$3/$2*100"%)"}'
    uptime | awk -F'load average:' '{print "   Load Average:"$2}'
    echo ""
    
    echo "=========================================="
    echo "Refreshing in 5 seconds..."
    sleep 5
done
