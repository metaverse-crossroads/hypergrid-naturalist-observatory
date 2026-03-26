function FirestormN() { PATH=vivarium/substrate/firestorm-7.2.3/official:$PATH vivarium/firestorm-7.2.3/fs-open.exe --login Test User$1 password --url http://127.0.0.1:9000 ; }

$ ./bin/cs++ species/libremetaverse/src/DeepSeaCommon.cs species/libremetaverse/2.5.7.90/src/DeepSeaClient.cs vivarium/libremetaverse-2.5.7.90/DeepSeaClient_Project/bin/Release/net8.0/DeepSeaClient.exe -main:DeepSeaClientWithVoice

function TestUserN() { ./bin/.NET vivarium/libremetaverse-2.5.7.90/DeepSeaClient_Project/bin/Release/net8.0/DeepSeaClient.dll --firstname Test --lastname User$1 --passw
ord password --uri http://127.0.0.1:9000 --timeout ${2:-300} microphone.wav ; }

$ ./bin/cs++ species/opensim-core/plugins/WebRTC/*.cs vivarium/opensim-core-0.9.3/bin/WebRTC.OpenSimStudioBridge.dll
