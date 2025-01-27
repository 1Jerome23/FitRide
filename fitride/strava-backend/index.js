const express = require('express');
const axios = require('axios'); 
const dotenv = require('dotenv');

const app = express();
const port = 3000;

const STRAVA_CLIENT_ID = '146485';
const STRAVA_CLIENT_SECRET = '6e8f87ec4856b0793c009aaf3dc17ff9a941f50f';

// The redirect URI is now set to Cloudflare Tunnel URL
const REDIRECT_URI = 'https://fitride.trycloudflare.com/callback';

console.log('STRAVA_CLIENT_ID:', STRAVA_CLIENT_ID);
console.log('STRAVA_CLIENT_SECRET:', STRAVA_CLIENT_SECRET);

app.listen(port, async () => {
  console.log(`Server is running on http://localhost:${port}`);
  
  const authorizationUrl = `https://www.strava.com/oauth/mobile/authorize?client_id=${STRAVA_CLIENT_ID}&redirect_uri=${REDIRECT_URI}&response_type=code&scope=activity:read_allapproval_prompt=force&login=true`;
  console.log('Authorization URL:', authorizationUrl);
  
  app.get('/auth', (req, res) => {
    res.redirect(authorizationUrl);
  });
  let accessToken = '';  // Variable to hold the access token

  app.get('/oauth/callback', async (req, res) => {
    const authorizationCode = req.query.code;
  
    try {
      const response = await axios.post('https://www.strava.com/oauth/token', {
        client_id: '146485',
        client_secret: '6e8f87ec4856b0793c009aaf3dc17ff9a941f50f',
        code: authorizationCode,
        grant_type: 'authorization_code',
      });
  
      const accessToken = response.data.access_token;
      console.log('Strava Access Token:', accessToken);
  
      res.send('OAuth callback received. Access token saved!');
    } catch (error) {
      console.error('Error during token exchange:', error);
      res.status(500).send('Error exchanging authorization code');
    }
  });
  
  
 
app.get('/profile', async (req, res) => {
  if (!accessToken) {
    return res.status(400).send('No access token found. Please authenticate first.');
  }

  try {
    const response = await axios.get('https://www.strava.com/api/v3/athlete', {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });

    console.log('User profile data:', response.data);
    res.json(response.data); 
  } catch (error) {
    console.error('Error fetching profile data:', error);
    res.status(500).send('Error fetching user profile data');
  }
});
app.get('/activities', async (req, res) => {
  if (!accessToken) {
    return res.status(400).send('No access token found. Please authenticate first.');
  }

  try {
    const response = await axios.get('https://www.strava.com/api/v3/athlete/activities', {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
      params: {
        per_page: 5,  // Fetch a maximum of 5 activities (you can adjust this)
        page: 1,      
      },
    });

    console.log('User activities:', response.data);
    res.json(response.data);  
  } catch (error) {
    console.error('Error fetching activities:', error);
    res.status(500).send('Error fetching activities');
  }
});

});
