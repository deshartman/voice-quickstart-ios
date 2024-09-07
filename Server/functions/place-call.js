/**
 * This function places a call based on the type of "to" passed in
 * 
 * event.To = Dial a PSTN number
 * event.identity = Dial a Client
 * event.domain = Dial a SIP domain
 * event.callerId = Caller ID for the call
 * 
 * Usage:
 * ======
 * https://' + context.DOMAIN_NAME + '/place-call?identity=alice&callerId=SomeName
 * 
 * // Assumes called via Prog Voice number and has a To: and From: numbers
 * https://' + context.DOMAIN_NAME + '/place-call?domain=somedomain.sip.twilio.com
 * https://' + context.DOMAIN_NAME + '/place-call             
 * 
 */
exports.handler = async function (context, event, callback) {
  const client = context.getTwilioClient();
  let to = "";
  let from = "";

  // console.info(`Event object:`, JSON.stringify(event));
  console.info(`Test Call: Event object.identity:`, event.identity);
  console.info(`Test Call: Event object.domain:`, event.domain);
  console.info("Test Call: Event object.callerId:", event.callerId);
  console.info(`Test Call: Event object.To:`, event.To);
  console.info(`Test Call: Event object.From:`, event.From);

  // If the identity is passed in, then dial the client.
  if (event.identity) {
    to = `client:${event.identity}`;
    // Check if there is a value for the "From" field, add it, else use event.callerId
    if (event.From) {
      from = `client:${event.From}`;
      console.log(`event.From check: Event object.From:`, event.From);
    }
    if (event.callerId) {
      from = `client:${event.callerId}`;
      console.log(`event.callerId check: Event object.callerId:`, event.callerId);
    } else {
      from = `client:anonymous`;
      console.log(`event.callerId check: Event object.callerId:`, 'anonymous');
    }

    console.info(`Call Out: Dialling Client ${to} with Caller ID ${from}`);
  }

  // If the SIP domain is passed in, then dial To number on the SIP domain, using the event.From as the caller ID.
  if (event.domain) {
    to = `${event.To}@${event.domain}`;
    from = event.From;
    console.info(`Call Out: Dialling sip:${to} with Caller ID ${from}`);
  }
  // If no identity or SIP domain is passed in and there is a To number, then dial the number.
  if (!event.identity && !event.domain && event.To) {  // Possibly redundant check later
    let to = event.To;
    let from = event.From;
    console.info(`Call Out: Dialling Number ${to} with Caller ID ${from}`);
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
      to: to,
      from: from
    });

    return callback(null, `Place Call: Dialling Client ${to} with Caller ID ${from} with call SID: ${call.sid}`);
  } catch (error) {
    return callback(`Error with call-out: ${error}`);
  }
}