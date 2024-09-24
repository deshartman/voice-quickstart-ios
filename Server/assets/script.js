document.addEventListener('DOMContentLoaded', function () {
    const identityInput = document.getElementById("identity");
    const displayNameInput = document.getElementById("display-name");
    const callButton = document.getElementById("call-button");

    const messageInput = document.getElementById('message');
    const sendMessageButton = document.getElementById('send-message-button');

    const statusMessage = document.getElementById("status-message");

    let isCallActive = false;
    let currentCallSid = ''; // Variable to store the current Call SID

    let statusPollInterval;

    function startStatusPolling(callSid) {
        statusPollInterval = setInterval(() => {
            fetchCallStatus(callSid);
        }, 1000); // Poll every 1 seconds
    }

    function stopStatusPolling() {
        if (statusPollInterval) {
            clearInterval(statusPollInterval);
        }
    }

    async function fetchCallStatus(callSid) {
        try {
            const response = await fetch('/call-status', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ callSid: callSid }),
            });

            const data = await response.json();

            if (data.error) {
                console.error('Error fetching call status:', data.error);
                return;
            }

            displayStatus(`Call status: ${data.status}`);

            if (data.status === 'completed') {
                handleCallEnded();
            }
        } catch (error) {
            console.error('Error:', error);
        }
    }

    function handleCallEnded() {
        stopStatusPolling();
        isCallActive = false;
        callButton.textContent = 'Call';
        callButton.classList.remove('hangup-button');
        callButton.classList.add('call-button');
        currentCallSid = '';
        displayStatus('Call ended');
    }

    function displayStatus(message, isError = false) {
        statusMessage.textContent = message;
        statusMessage.className = 'status-message ' + (isError ? 'error' : 'success');
    }

    function clearStatus() {
        statusMessage.textContent = '';
        statusMessage.className = 'status-message';
    }

    callButton.addEventListener('click', async function () {
        clearStatus();
        try {
            const response = await fetch('/place-call', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    identity: isCallActive ? '' : identity.value,
                    displayName: displayNameInput.value,
                    callSid: isCallActive ? currentCallSid : ''
                }),
            });

            const data = await response.text();
            console.log('Server response:', data);

            if (data.includes('Error')) {
                throw new Error(data);
            }

            if (data.includes('Dialling Client')) {
                isCallActive = true;
                callButton.textContent = 'Hang Up';
                callButton.classList.remove('call-button');
                callButton.classList.add('hangup-button');
                // Extract Call SID from the response
                const sidMatch = data.match(/call SID: (CA[a-f0-9]+)/);
                if (sidMatch) {
                    currentCallSid = sidMatch[1]; // Store the Call SID in the variable
                    startStatusPolling(currentCallSid);
                }
                displayStatus('Call initiated successfully');
            } else if (data.includes('has been disconnected')) {
                handleCallEnded();
            }
        } catch (error) {
            console.error('Error:', error);
            displayStatus('An error occurred: ' + error.message, true);
        }
    });

    sendMessageButton.addEventListener('click', async function () {
        clearStatus();
        if (isCallActive) {
            try {
                const response = await fetch('/send-message', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        callSid: currentCallSid,
                        message: messageInput.value,
                    }),
                });

                const data = await response.text();
                console.log('Server response:', data);

                if (data.includes('Error')) {
                    throw new Error(data);
                }

                displayStatus('Message sent successfully');
                messageInput.value = '';
            } catch (error) {
                console.error('Error:', error);
                displayStatus('An error occurred while sending the message: ' + error.message, true);
            }
        } else {
            displayStatus('Please start a call before sending a message', true);
        }
    });
});