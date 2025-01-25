const express = require('express');
const axios = require('axios'); // Import axios
const dotenv = require('dotenv');

// Initialize Express
const app = express();
const port = 3000; // Default port is 3000

// Hardcoded Strava OAuth credentials
const STRAVA_CLIENT_ID = '145840';
const STRAVA_CLIENT_SECRET = '63ef4f6d5aa9f156ba84279c51569261cb37e905';

// The redirect URI is now set to Cloudflare Tunnel URL
const REDIRECT_URI = 'https://amend-adjustable-generators-marcus.trycloudflare.com/callback';

console.log('STRAVA_CLIENT_ID:', STRAVA_CLIENT_ID);
console.log('STRAVA_CLIENT_SECRET:', STRAVA_CLIENT_SECRET);

// Start Express server
app.listen(port, async () => {
  console.log(`Server is running on http://localhost:${port}`);
  
  // Generate the authorization URL using the hardcoded values
  const authorizationUrl = `https://www.strava.com/oauth/mobile/authorize?client_id=${STRAVA_CLIENT_ID}&redirect_uri=${REDIRECT_URI}&response_type=code&scope=read`;
  console.log('Authorization URL:', authorizationUrl);
  
  // Serve the authorization URL on your route
  app.get('/auth', (req, res) => {
    res.redirect(authorizationUrl);
  });
  let accessToken = '';  // Variable to hold the access token

  // OAuth callback route to exchange the code for an access token
  app.get('/callback', async (req, res) => {
    const code = req.query.code;  // The authorization code from Strava
  
    try {
      // Exchange code for access token
      const response = await axios.post('https://www.strava.com/oauth/token', null, {
        params: {
          client_id: STRAVA_CLIENT_ID,
          client_secret: STRAVA_CLIENT_SECRET,
          code: code,
          grant_type: 'authorization_code',
        },
      });
  
      // Save the access token dynamically
      accessToken = response.data.access_token;
      console.log('Strava Access Token:', accessToken);
  
      res.send('OAuth callback received. Access token saved!');
    } catch (error) {
      console.error('Error exchanging authorization code:', error);
      res.status(500).send('Error exchanging authorization code');
    }
  });
  
 
app.get('/profile', async (req, res) => {
  if (!accessToken) {
    return res.status(400).send('No access token found. Please authenticate first.');
  }

  try {
    // Make the API request to fetch user profile data
    const response = await axios.get('https://www.strava.com/api/v3/athlete', {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });

    console.log('User profile data:', response.data);
    res.json(response.data);  // Send the user profile data as JSON in the response
  } catch (error) {
    console.error('Error fetching profile data:', error);
    res.status(500).send('Error fetching user profile data');
  }
});

});
