/**
 * This function places a call based on the type of "to" passed in
 * or disconnects an active call if a callSid is provided
 * 
 * event.To = Dial a PSTN number
 * event.identity = Dial a Client
 * event.domain = Dial a SIP domain
 * event.callerId = Caller ID for the call
 * event.callSid = Disconnect an active call
 * 
 * Usage:
 * ======
 * https://' + context.DOMAIN_NAME + '/place-call?identity=alice&callerId=SomeName
 * https://' + context.DOMAIN_NAME + '/place-call?domain=somedomain.sip.twilio.com
 * https://' + context.DOMAIN_NAME + '/place-call             
 * https://' + context.DOMAIN_NAME + '/place-call?callSid=CAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
 * 
 */
exports.handler = async function (context, event, callback) {
  const client = context.getTwilioClient();

  if (event.callSid) {
    try {
      await client.calls(event.callSid).update({ status: 'completed' });
      return callback(null, `Call with SID ${event.callSid} has been disconnected.`);
    } catch (error) {
      return callback(`Error disconnecting call: ${error}`);
    }
  }

  let to = "";
  let from = "";
  const displayName = event.displayName || event.callerId || 'Trusted%20Caller';  // Default to URL Encoded "Trusted Caller" if no display name is passed in
  console.info(`Place Call: Display Name ${displayName}`);

  // console.info(`Event object:`, JSON.stringify(event));
  console.info(`Test Call: Event object.identity:`, event.identity);
  console.info(`Test Call: Event object.domain:`, event.domain);
  console.info("Test Call: Event object.callerId:", event.callerId);
  console.info(`Test Call: Event object.To:`, event.To);
  console.info(`Test Call: Event object.From:`, event.From);
  console.info("Call SID:", event.callSid);

  // If the identity is passed in, then dial the client.
  if (event.identity) {
    to = `client:${event.identity}`;
    console.info(`identity.event.to: ${to}`);
    // Check if there is a value for the "From" field, add it, else use event.callerId
    if (event.From) {
      from = `client:${event.From}`;
      console.log(`identity.event.From check: Event object.From:`, event.From);
    }
    if (event.callerId) {
      from = `client:${event.callerId}`;
      console.log(`identity.event.callerId check: Event object.callerId:`, event.callerId);
    } else {
      from = `client:anonymous`;
      console.log(`identity.event.callerId check: Event object.callerId:`, 'anonymous');
    }

    console.info(`Place Call: Dialling Client ${to} with Caller ID ${from}`);
  }

  // If the SIP domain is passed in, then dial To number on the SIP domain, using the event.From as the caller ID.
  if (event.domain) {
    to = `${event.To}@${event.domain}`;
    from = event.From;
    console.info(`Place Call: Dialling sip:${to} with Caller ID ${from}`);
  }
  // If no identity or SIP domain is passed in and there is a To number, then dial the number.
  if (!event.identity && !event.domain && event.To) {  // Possibly redundant check later
    let to = event.To;
    let from = event.From;
    console.info(`Place Call: Dialling Number ${to} with Caller ID ${from}`);
  }

  if (!to) {
    return callback(`Error: No "To" number or "identity" or "domain" provided.`);
  }
  if (!from) {
    return callback(`Error: No "From" number or "callerId" provided.`);
  }

  // Create a new Client call
  try {
    var url = 'https://twilio-retell-serverless-4508-dev.twil.io/start?agent_id=a5d4fc385db7892e2d98abacede2a11d'
    const call = await client.calls.create({
      url: url,
      to: `${to}?displayName=${displayName}`,
      from: from,
      parameter: {
        displayName: displayName
      }
    });

    return callback(null, `Place Call: Dialling Client ${to} with Caller ID ${from} and Display Name ${displayName} with call SID: ${call.sid}`);
  } catch (error) {
    return callback(`Error with call-out: ${error}`);
  }
}