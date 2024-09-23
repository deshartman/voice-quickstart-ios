document.addEventListener('DOMContentLoaded', function () {
    const identityInput = document.getElementById("identity");
    const displayNameInput = document.getElementById("display-name");
    const displayMessage = document.getElementById("display-message");
    const callButton = document.getElementById("call-button");

    const messageInput = document.getElementById('message');
    const sendMessageButton = document.getElementById('send-message-button');

    const statusMessage = document.getElementById("status-message");

    let isCallActive = false;
    let currentCallSid = ''; // Variable to store the current Call SID

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
                    displayMessage: displayMessage.value,
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
                }
                displayStatus('Call initiated successfully');
            } else if (data.includes('has been disconnected')) {
                isCallActive = false;
                callButton.textContent = 'Call';
                callButton.classList.remove('hangup-button');
                callButton.classList.add('call-button');
                currentCallSid = ''; // Clear the Call SID
                displayStatus('Call ended');
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