const express = require('express');
const axios = require('axios');
const qs = require('querystring');
const app = express();
const port = 3000;

app.use(express.json());

const STRAVA_CLIENT_ID = '146485';
const STRAVA_CLIENT_SECRET = '6e8f87ec4856b0793c009aaf3dc17ff9a941f50f';
const REDIRECT_URI = 'https://fitride.trycloudflare.com/callback';
const WEBHOOK_CALLBACK_URL = 'https://fitride.trycloudflare.com/webhook';
const VERIFY_TOKEN = '510a9fdca8569583355fc3c158c3cb0a2583f6c1';

let userTokens = {}; 

app.listen(port, () => {
  console.log(`Server is running on http://localhost:${port}`);
});

app.get('/auth', (req, res) => {
  const authorizationUrl = `https://www.strava.com/oauth/mobile/authorize?client_id=${STRAVA_CLIENT_ID}&redirect_uri=${REDIRECT_URI}&response_type=code&scope=activity:read_all,activity:write&approval_prompt=force`;
  console.log('Authorization URL:', authorizationUrl);
  res.redirect(authorizationUrl);
});

app.get('/callback', async (req, res) => {
  const authorizationCode = req.query.code;

  try {
    const response = await axios.post('https://www.strava.com/oauth/token', {
      client_id: STRAVA_CLIENT_ID,
      client_secret: STRAVA_CLIENT_SECRET,
      code: authorizationCode,
      grant_type: 'authorization_code',
    });

    userTokens[response.data.athlete.id] = response.data.access_token;
    console.log('Strava Access Token:', response.data.access_token);

    res.send('OAuth callback received. Access token saved!');
  } catch (error) {
    console.error('Error during token exchange:', error.response ? error.response.data : error.message);
    res.status(500).send('Error exchanging authorization code');
  }
});

app.get('/profile', async (req, res) => {
  const athleteId = req.query.athlete_id;
  const accessToken = userTokens[athleteId];

  if (!accessToken) {
    return res.status(400).send('No access token found. Please authenticate first.');
  }

  try {
    const response = await axios.get('https://www.strava.com/api/v3/athlete', {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    res.json(response.data);
  } catch (error) {
    console.error('Error fetching profile data:', error.response ? error.response.data : error.message);
    res.status(500).send('Error fetching user profile data');
  }
});

app.get('/activities', async (req, res) => {
  const athleteId = req.query.athlete_id;
  const accessToken = userTokens[athleteId];

  if (!accessToken) {
    return res.status(400).send('No access token found. Please authenticate first.');
  }

  try {
    const response = await axios.get('https://www.strava.com/api/v3/athlete/activities', {
      headers: { Authorization: `Bearer ${accessToken}` },
      params: { per_page: 5, page: 1 },
    });
    res.json(response.data);
  } catch (error) {
    console.error('Error fetching activities:', error.response ? error.response.data : error.message);
    res.status(500).send('Error fetching activities');
  }
});

app.get('/webhook', (req, res) => {
  const hubChallenge = req.query['hub.challenge'];
  const verifyToken = req.query['hub.verify_token'];

  if (verifyToken === VERIFY_TOKEN) { 
    console.log('Webhook verified');
    res.status(200).json({ 'hub.challenge': hubChallenge }); 
  } else {
    console.error('Invalid verify token');
    res.status(403).send('Invalid verify token');
  }
});

// Webhook event handler
app.post('/webhook', (req, res) => {
  const eventData = req.body;

  console.log('Received webhook event:', eventData);

  if (eventData.aspect_type === 'create' && eventData.object_type === 'activity') {
    const athleteId = eventData.owner_id;
    const activityId = eventData.object_id;

    console.log(`New activity created by athlete ${athleteId}: Activity ID ${activityId}`);

    const accessToken = userTokens[athleteId];

    if (!accessToken) {
      console.error(`No access token found for athlete ${athleteId}`);
      return res.status(400).send('No access token found');
    }

    axios.get(`https://www.strava.com/api/v3/activities/${activityId}`, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    })
    .then(response => {
      console.log('Activity details:', response.data);
    })
    .catch(error => {
      console.error('Error fetching activity details:', error.response ? error.response.data : error.message);
    });
  }

  res.status(200).send('Webhook received'); 
});
