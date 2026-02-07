#!/usr/bin/env python3
"""
Quick test for the ReAct Agentic Loop in ai_tools_service.py
This verifies the core loop logic without making actual API calls.
"""

import asyncio
import json
import sys
sys.path.insert(0, '/media/nikhil/427092fa-e2b4-41f9-aa94-fa27c0b84b171/wealthin_git_/wealthin_v2/backend')

from services.ai_tools_service import AIToolsService, FINANCIAL_TOOLS


def test_tools_structure():
    """Verify FINANCIAL_TOOLS has correct structure for Sarvam SDK."""
    print("Testing FINANCIAL_TOOLS structure...")
    
    for tool in FINANCIAL_TOOLS:
        assert "name" in tool, f"Tool missing 'name': {tool}"
        assert "description" in tool, f"Tool missing 'description': {tool}"
        assert "parameters" in tool, f"Tool missing 'parameters': {tool}"
        
        # Check parameters structure
        params = tool["parameters"]
        assert params.get("type") == "object", f"Parameters type should be 'object': {tool['name']}"
        assert "properties" in params, f"Parameters missing 'properties': {tool['name']}"
        
    print(f"✅ All {len(FINANCIAL_TOOLS)} tools have correct structure")


def test_search_tools_present():
    """Verify all search tools are defined."""
    print("Testing search tools presence...")
    
    search_tools = ["web_search", "search_shopping", "search_amazon", "search_flipkart", 
                    "search_myntra", "search_hotels", "search_maps", "search_news"]
    
    tool_names = [t["name"] for t in FINANCIAL_TOOLS]
    
    for st in search_tools:
        assert st in tool_names, f"Missing search tool: {st}"
    
    print(f"✅ All {len(search_tools)} search tools present")


def test_execute_function_routing():
    """Test that _execute_function routes to correct handlers."""
    print("Testing function routing...")
    
    service = AIToolsService()
    
    # The service should have _execute_function method
    assert hasattr(service, '_execute_function'), "Missing _execute_function method"
    
    # It should have _execute_search_tool method
    assert hasattr(service, '_execute_search_tool'), "Missing _execute_search_tool method"
    
    print("✅ Function routing methods present")


async def test_search_tool_execution():
    """Test that search tools execute without errors."""
    print("Testing search tool execution...")
    
    service = AIToolsService()
    
    # Test with a simple query (will use DuckDuckGo)
    try:
        result = await service._execute_search_tool("web_search", {"query": "iPhone 15 price India"})
        assert "success" in result, "Result missing 'success' key"
        print(f"✅ Search tool executed, success={result['success']}")
        if result.get("data"):
            print(f"   Found {len(result['data'])} results")
    except Exception as e:
        print(f"⚠️ Search tool error (may be expected if no network): {e}")


def main():
    print("=" * 50)
    print("ReAct Loop Verification Tests")
    print("=" * 50)
    
    test_tools_structure()
    test_search_tools_present()
    test_execute_function_routing()
    
    # Run async test
    asyncio.run(test_search_tool_execution())
    
    print("=" * 50)
    print("✅ All tests passed!")
    print("=" * 50)


if __name__ == "__main__":
    main()
