exports.handler = function (context, event, callback) {

  const AccessToken = Twilio.jwt.AccessToken;
  const VoiceGrant = AccessToken.VoiceGrant;

  const twilioAccountSid = context.ACCOUNT_SID;
  const twilioApiKey = context.API_KEY_SID;
  const twilioApiSecret = context.API_SECRET;

  const outgoingApplicationSid = context.APP_SID;
  const pushCredentialSid = context.PUSH_CREDENTIAL_SID;
  const identity = event.identity || 'user';

  const voiceGrant = new VoiceGrant({
    outgoingApplicationSid: outgoingApplicationSid,
    pushCredentialSid: pushCredentialSid
  });

  // Set the TTL for the token to 1 hour or what is passed in on the ttl query parameter
  let ttl = event.ttl || 3600;  // Time to live for the token in seconds. Default is 1 hour.

  const token = new AccessToken(
    twilioAccountSid,
    twilioApiKey,
    twilioApiSecret,
    {
      identity: identity,
      ttl: ttl
    }
  );
  token.addGrant(voiceGrant);
  token.identity = identity;

  // Show first few characters of the token
  // console.log(`Issued token for: ${identity} with token lasting ${ttl}: ${token.toJwt().substring(0, 50)}...`);
  console.log(`Issued token for: ${identity} with token lasting ${ttl}: ${token.toJwt()}`);
  // Serialize the token to a JWT string
  callback(null, token.toJwt());
};