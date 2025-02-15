const express = require('express');
const axios = require('axios');
const qs = require('querystring');
const app = express();
const port = 3000;

app.use(express.json());

const STRAVA_CLIENT_ID = '146485';
const STRAVA_CLIENT_SECRET = '6e8f87ec4856b0793c009aaf3dc17ff9a941f50f';
const REDIRECT_URI = 'https://fitride.uk/callback';
const WEBHOOK_CALLBACK_URL = 'https://fitride.uk/webhook';
const VERIFY_TOKEN = 'STRAVA';

let userTokens = {}; 

app.listen(port, () => {
  console.log(`Server is running on http://localhost:${port}`);
});

app.get('/auth', (req, res) => {
  const authorizationUrl = `https://www.strava.com/oauth/mobile/authorize?client_id=${STRAVA_CLIENT_ID}&redirect_uri=${REDIRECT_URI}&response_type=code&scope=activity:read_all&approval_prompt=force`;
  console.log('Authorization URL:', authorizationUrl);
  res.redirect(authorizationUrl);
});

app.get('/callback', async (req, res) => {
  const authorizationCode = req.query.code;
  const idToken = req.headers.authorization?.split('Bearer ')[1];

  if (!idToken) {
    return res.status(401).send('Unauthorized: Missing Firebase ID token');
  }

  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const firebaseUid = decodedToken.uid;

    const response = await axios.post('https://www.strava.com/oauth/token', {
      client_id: STRAVA_CLIENT_ID,
      client_secret: STRAVA_CLIENT_SECRET,
      code: authorizationCode,
      grant_type: 'authorization_code',
    });

    const { athlete, access_token } = response.data;
    const athleteId = athlete.id; 

    await admin.firestore().collection('user_tokens').doc(firebaseUid).set({
      accessToken: access_token,
    });

    await admin.firestore().collection('user_mappings').doc(athleteId.toString()).set({
      athleteId: athleteId,
      uid: firebaseUid,
    });

    console.log(`Mapping created: Strava athleteId ${athleteId} -> Firebase UID ${firebaseUid}`);
    res.send('OAuth callback received. Access token and mapping saved!');
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
    console.log('✅ Webhook verified');
    res.status(200).json({ 'hub.challenge': hubChallenge }); 
  } else {
    console.error('❌ Invalid verify token');
    res.status(403).send('Invalid verify token');
  }
});


app.post('/webhook', async (req, res) => {
  const eventData = req.body;
  const athleteId = eventData.owner_id;

  console.log('Received webhook event:', eventData);
  console.log('Strava Athlete ID:', athleteId);

  try {

    const userMappingRef = admin.firestore().collection('athletes').doc(athleteId.toString());
    const userMappingSnapshot = await userMappingRef.get();

    if (!userMappingSnapshot.exists) {
      throw new Error(`No user mapping found for Strava athlete ${athleteId}`);
    }

    const firebaseUid = userMappingSnapshot.data().app_id; 
    console.log('Firebase UID:', firebaseUid);

    const userDeviceTokensRef = admin.firestore().collection('user_device_tokens').doc(firebaseUid);
    const userDeviceTokensSnapshot = await userDeviceTokensRef.get();

    if (!userDeviceTokensSnapshot.exists || !userDeviceTokensSnapshot.data().tokens) {
      console.error(`No FCM tokens found for user with UID ${firebaseUid}`);
      return res.status(200).send('Webhook received but no FCM tokens available');
    }

    const fcmTokens = userDeviceTokensSnapshot.data().tokens;

    const tokensRef = admin.firestore().collection('user_tokens').doc(firebaseUid);
    const tokensSnapshot = await tokensRef.get();
    const accessToken = tokensSnapshot.data().accessToken;

    const activityResponse = await axios.get(`https://www.strava.com/api/v3/activities/${eventData.object_id}`, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    const activityData = activityResponse.data;

    await admin.firestore().collection('activities').doc(activityData.id.toString()).set({
      'user_id': firebaseUid,
      'name': activityData.name || 'Unnamed Activity',
      'distance': (activityData.distance / 1000).toFixed(2), 
      'start_date': activityData.start_date,
      'type': activityData.type,
      'average_speed': (activityData.average_speed * 3.6).toFixed(2),
      'average_heartrate': activityData.average_heartrate || null,
      'calories_burned': activityData.calories || null,
    });
    console.log('Activity data saved successfully!');

    const promises = fcmTokens.map((registrationToken) => {
      const message = {
        data: {
          title: 'New Activity Recorded',
          body: `You just recorded a new activity: ${activityData.name || 'Unnamed Activity'}`,
        },
        token: registrationToken,
      };

      return admin.messaging().send(message)
        .then((response) => {
          console.log(`Successfully sent message to token ${registrationToken}:`, response);
        })
        .catch((error) => {
          console.error(`Error sending message to token ${registrationToken}:`, error.message);
        });
    });

    await Promise.all(promises);
    console.log('All notifications have been processed.');
  } catch (error) {
    console.error('Error processing webhook event:', error.message);
    return res.status(500).send('Error processing webhook event');
  }

  res.status(200).send('Webhook received');
});