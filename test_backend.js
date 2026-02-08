#!/usr/bin/env node

/**
 * Backend Health Check Script
 * 
 * This script tests the Hostel Face Attendance backend API
 * to verify it's running correctly on Render.
 */

const BACKEND_URL = 'https://hostel-attendance-nc8a.onrender.com/api';

async function checkEndpoint(name, url, options = {}) {
  console.log(`\n🔍 Testing ${name}...`);
  console.log(`   URL: ${url}`);
  
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 60000); // 60s timeout
    
    const startTime = Date.now();
    const response = await fetch(url, {
      ...options,
      signal: controller.signal,
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
    });
    clearTimeout(timeoutId);
    
    const duration = Date.now() - startTime;
    const data = await response.json();
    
    console.log(`   ✅ Status: ${response.status}`);
    console.log(`   ⏱️  Response Time: ${duration}ms`);
    console.log(`   📦 Response:`, JSON.stringify(data, null, 2));
    
    return { success: true, status: response.status, data, duration };
  } catch (error) {
    console.log(`   ❌ Error: ${error.message}`);
    if (error.name === 'AbortError') {
      console.log(`   ⚠️  Request timed out (60s) - Service may be cold-starting`);
    }
    return { success: false, error: error.message };
  }
}

async function runTests() {
  console.log('🚀 BACKEND HEALTH CHECK');
  console.log('='.repeat(60));
  console.log(`Backend URL: ${BACKEND_URL}`);
  console.log('='.repeat(60));

  const results = [];

  // Test 1: Health Check
  results.push(await checkEndpoint(
    'Health Check',
    `${BACKEND_URL}/health`
  ));

  await new Promise(resolve => setTimeout(resolve, 2000));

  // Test 2: Login (Test credentials)
  results.push(await checkEndpoint(
    'Login (Warden)',
    `${BACKEND_URL}/auth/login`,
    {
      method: 'POST',
      body: JSON.stringify({
        username: 'warden',
        password: 'warden123',
      }),
    }
  ));

  await new Promise(resolve => setTimeout(resolve, 2000));

  // Test 3: Login (Admin)
  results.push(await checkEndpoint(
    'Login (Admin)',
    `${BACKEND_URL}/auth/login`,
    {
      method: 'POST',
      body: JSON.stringify({
        username: 'admin',
        password: 'admin123',
      }),
    }
  ));

  // Summary
  console.log('\n' + '='.repeat(60));
  console.log('📊 TEST SUMMARY');
  console.log('='.repeat(60));
  
  const passed = results.filter(r => r.success).length;
  const total = results.length;
  
  console.log(`   Total Tests: ${total}`);
  console.log(`   Passed: ${passed} ✅`);
  console.log(`   Failed: ${total - passed} ❌`);
  
  if (passed === total) {
    console.log('\n✨ All tests passed! Backend is running correctly.');
  } else {
    console.log('\n⚠️  Some tests failed. Check the errors above.');
    console.log('\nCommon Issues:');
    console.log('   1. Backend is cold-starting (free tier sleeps after inactivity)');
    console.log('   2. MongoDB connection issue');
    console.log('   3. Environment variables not set on Render');
    console.log('\nSolutions:');
    console.log('   1. Wait 30-60 seconds and run the test again');
    console.log('   2. Check Render logs for errors');
    console.log('   3. Verify environment variables on Render dashboard');
  }

  console.log('\n' + '='.repeat(60));
  
  if (results[0]?.data?.status === 'ok') {
    console.log('\n✅ BACKEND IS ONLINE AND RESPONDING');
  } else if (results[0]?.error?.includes('timeout')) {
    console.log('\n⏳ BACKEND IS COLD-STARTING (this can take 30-60 seconds on free tier)');
    console.log('   Please wait and try again in a minute.');
  } else {
    console.log('\n❌ BACKEND IS NOT RESPONDING');
    console.log('   Please check Render deployment logs.');
  }
}

// Run the tests
runTests().catch(console.error);
