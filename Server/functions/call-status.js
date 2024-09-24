exports.handler = async function (context, event, callback) {
    const client = context.getTwilioClient();
    const callSid = event.callSid;

    if (!callSid) {
        return callback(null, { error: 'Call SID is required' });
    }

    try {
        const call = await client.calls(callSid).fetch();
        return callback(null, {
            status: call.status,
            duration: call.duration
        });
    } catch (error) {
        console.error('Error fetching call status:', error);
        return callback(null, { error: 'Failed to fetch call status' });
    }
};