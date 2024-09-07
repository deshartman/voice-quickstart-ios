exports.handler = function (context, event, callback) {
  // console.info(`Event object:`, JSON.stringify(event));
  console.info(`Call Out: Event object.identity:`, event.identity);
  console.info(`Call Out: Event object.To:`, event.To);
  console.info(`Call Out: Event object.From:`, event.From);

  try {
    const voiceResponse = new Twilio.twiml.VoiceResponse();

    // If the identity is passed in, then dial the client.
    if (event.identity) {
      to = event.identity;
      from = event.From;
      console.info(`Call Out: Dialling Client ${to} with Caller ID ${from}`);
      voiceResponse.dial({ callerId: from }).client(to);
      return callback(null, voiceResponse);
    }

    // If the SIP domain is passed in, then dial the SIP domain.
    if (event.domain) {
      to = `${event.To}@${event.domain}`;
      from = event.From;
      console.info(`Call Out: Dialling SIP ${to} with Caller ID ${from}`);
      voiceResponse.dial({ callerId: from }).sip(to);
      return callback(null, voiceResponse);
    }

    // If no "To" number is provided, then just echo the message back to the caller.
    if (event.To === '') {
      let from = event.From;
      console.info(`Call Out: Echoing message to caller with Caller ID ${from}`);
      voiceResponse.say('Congratulations! You have made your first Client call! PAssing you over to our clever A.I. now');
      // Redirect to the new URL
      voiceResponse.redirect('https://twilio-retell-serverless-4508-dev.twil.io/start?agent_id=a5d4fc385db7892e2d98abacede2a11d');
      return callback(null, voiceResponse);
    }

    // If no identity or SIP domain is passed in and there is a To number, then dial the number.
    if (!event.identity && !event.domain && event.To) {  // Possibly redundant check later
      let to = event.To;
      let from = event.From;
      console.info(`Call Out: Dialling Number ${to} with Caller ID ${from}`);
      voiceResponse.dial({ callerId: from }).number(to);
      return callback(null, voiceResponse);
    }
  } catch (error) {
    return callback(`Call Out: Error with call-out: ${error}`);
  }
}