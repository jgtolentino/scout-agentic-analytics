#!/bin/bash
# Validate Fully Agent Setup
# Checks all components are properly configured and working

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 Validating Fully Agent Setup..."
echo "================================="

# Check Python syntax
echo -e "\n${YELLOW}Checking Python scripts...${NC}"
for script in skills/fully/*.py utils/*.py; do
    if [ -f "$script" ]; then
        if python3 -m py_compile "$script" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} $script"
        else
            echo -e "${RED}✗${NC} $script - Syntax error"
            python3 -m py_compile "$script"
        fi
    fi
done

# Check bash script
echo -e "\n${YELLOW}Checking bash scripts...${NC}"
if bash -n scripts/deploy_supabase_schema.sh 2>/dev/null; then
    echo -e "${GREEN}✓${NC} scripts/deploy_supabase_schema.sh"
else
    echo -e "${RED}✗${NC} scripts/deploy_supabase_schema.sh - Syntax error"
fi

# Check file permissions
echo -e "\n${YELLOW}Checking file permissions...${NC}"
for file in scripts/*.sh skills/fully/*.py utils/*.py; do
    if [ -f "$file" ] && [ -x "$file" ]; then
        echo -e "${GREEN}✓${NC} $file is executable"
    elif [ -f "$file" ]; then
        echo -e "${YELLOW}!${NC} $file is not executable (fixing...)"
        chmod +x "$file"
    fi
done

# Validate YAML references
echo -e "\n${YELLOW}Validating fully.yaml handler references...${NC}"
handlers=(
    "skills/fully/json_to_pg.py"
    "skills/fully/seed_supabase.py"
    "skills/fully/generate_models.py"
    "skills/fully/generate_component.ts"
    "skills/fully/schema_summary.py"
    "scripts/deploy_supabase_schema.sh"
)

for handler in "${handlers[@]}"; do
    if [ -f "$handler" ]; then
        echo -e "${GREEN}✓${NC} $handler exists"
    else
        echo -e "${RED}✗${NC} $handler missing!"
    fi
done

# Test MCP context loader
echo -e "\n${YELLOW}Testing MCP context loader...${NC}"
if python3 utils/load_supabase_context.py validate 2>/dev/null; then
    echo -e "${GREEN}✓${NC} MCP context validation passed"
else
    echo -e "${YELLOW}!${NC} MCP context not found (this is OK if using env vars)"
fi

# Check dependencies
echo -e "\n${YELLOW}Checking Python dependencies...${NC}"
deps=("supabase" "typer" "pydantic")
for dep in "${deps[@]}"; do
    if python3 -c "import $dep" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $dep installed"
    else
        echo -e "${RED}✗${NC} $dep not installed"
    fi
done

# Summary
echo -e "\n${GREEN}=============================
VALIDATION COMPLETE
=============================${NC}"

echo -e "\n${YELLOW}Quick Test Commands:${NC}"
echo "1. Test schema inference:"
echo "   python3 skills/fully/json_to_pg.py --help"
echo ""
echo "2. Test MCP context:"
echo "   python3 utils/load_supabase_context.py show"
echo ""
echo "3. Test with sample data:"
echo "   echo '[{"id":1,"name":"test"}]' > test.json"
echo "   python3 skills/fully/json_to_pg.py test.json"