/**
 * This function sends a custom message to an active call client
 * 
 * event.callSid = Call SID for the call
 * 
 * Usage:
 * ======
 * https://' + context.DOMAIN_NAME + '/send-message?callSid=CAxxxxxxxx&message="Hello World"
 * 
 * 
 */
exports.handler = async function (context, event, callback) {
  const client = context.getTwilioClient();
  const callSid = event.callSid;
  const message = event.message || "Hello from the server side!";

  console.info("Message Call: Event object.callSID:", callSid);
  console.info(`Message Call: Event object.Message:`, message);

  try {
    // Create the content object
    const contentObject = {
      message: message
    };

    // Stringify the content object
    const contentString = JSON.stringify(contentObject);

    // Note: We're not URL-encoding the entire string, as Twilio will handle that
    const userDefinedMessage = await client
      .calls(callSid)
      .userDefinedMessages.create({
        content: contentString
      });

    console.log(`Message sent to call ${callSid}: ${userDefinedMessage.content}`);
    return callback(null, `Message sent to call ${callSid}: ${userDefinedMessage.content}`);

  } catch (error) {
    console.error(`Error sending message to call: ${error}`);
    return callback(`Error sending message to call: ${error}`);
  }
}
