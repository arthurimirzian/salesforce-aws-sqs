public class Sqs {
    public class AwsException extends Exception {}
    
    private static String aws_region {get;set;}
    private static String aws_account_id {get;set;}
    private static String aws_queue_name {get;set;}
    private static String host {get;set;}
    private static String endpoint {get;set;}
    private static String request_parameters {get;set;}
    
    private static Final String aws_service = 'sqs';
    private static Final String content_type = 'application/x-www-form-urlencoded';
    
    // Create a date for headers and the credential string
    private static Final Datetime now = Datetime.now();
    private static Final String amz_date = now.formatGmt('YMMdd') + 'T' + now.formatGmt('HHmmss') + 'Z';
    private static Final String date_stamp = now.formatGmt('YMMdd');
    
    // Read AWS access key from env. variables or configuration file. 
    // Best practice is NOT to embed credentials in code.
    private static Map < String, String > credential_map {get;set;}
    private static String access_key = getCredentialValueFromName('aws_sqs_access_key');
    private static String secret_key = getCredentialValueFromName('aws_sqs_secret_key');
    
    private static String getCredentialValueFromName(String cred_name) {
        if (Sqs.credential_map == null) {
            List < SystemSetting__mdt > mcs = [
                SELECT MasterLabel, Value__c
                FROM SystemSetting__mdt
                WHERE MasterLabel = 'aws_sqs_access_key'
                OR MasterLabel = 'aws_sqs_secret_key'
            ];
            Map < String, String > credential_map = new Map < String, String > ();
            for (SystemSetting__mdt c: mcs) {
                credential_map.put(c.MasterLabel, c.Value__c);
            }
            Sqs.credential_map = credential_map;
        }
        return Sqs.credential_map.get(cred_name);
    }
    
    public static void SendMessage(String aws_region, String aws_account_id, String aws_queue_name, String message_body) {
        if (aws_region == null) {
            throw new AwsException('Region is mandatory');
        } else if (aws_queue_name == null) {
            throw new AwsException('Queue is mandatory');
        } else if (aws_account_id == null) {
            throw new AwsException('Account ID is mandatory');
        } else if (message_body == null) {
            throw new AwsException('Body is mandatory');
        }
        // ************* REQUEST VALUES *************
        Sqs.aws_region = aws_region;
        Sqs.aws_queue_name = aws_queue_name;
        Sqs.aws_account_id = aws_account_id;
        Sqs.request_parameters = 'Action=SendMessage&MessageBody=' + message_body;
        Sqs.host = aws_service + '.' + aws_region + '.amazonaws.com';
        Sqs.endpoint = 'https://' + host + '/' + aws_account_id + '/' + aws_queue_name;
        
        String canonical_request = Sqs.createCanonicalRequest();
        String string_to_sign = Sqs.createTheStringToSign(canonical_request);
        String signature = Sqs.calculateTheSignature(string_to_sign);
        String authorization_header = Sqs.addSigningInfoToTheRequest(signature);
        
        Sqs.sendRequest('POST', authorization_header, amz_date, request_parameters, endpoint);    
    }
    
    public static void SendMessageBatch(String aws_region, String aws_account_id, String aws_queue_name, List<String> message_bodies) {
        if (aws_region == null) {
            throw new AwsException('Region is mandatory');
        } else if (aws_queue_name == null) {
            throw new AwsException('Queue is mandatory');
        } else if (aws_account_id == null) {
            throw new AwsException('Account ID is mandatory');
        } else if (message_bodies == null || message_bodies.size() == 0) {
            throw new AwsException('Body is mandatory');
        }
        // ************* REQUEST VALUES *************
        Sqs.aws_region = aws_region;
        Sqs.aws_queue_name = aws_queue_name;
        Sqs.aws_account_id = aws_account_id;
        String message_body = '';
        Sqs.request_parameters = 'Action=SendMessageBatch';
        for(Integer i = 0;i<message_bodies.size();i++){
            Sqs.request_parameters = Sqs.request_parameters 
                + '&SendMessageBatchRequestEntry.'+(i+1)+'.Id=msg_0'+(i+1)
                + '&SendMessageBatchRequestEntry.'+(i+1)+'.MessageBody='+EncodingUtil.urlEncode(message_bodies[i], 'UTF-8');
        }
        Sqs.host = aws_service + '.' + aws_region + '.amazonaws.com';
        Sqs.endpoint = 'https://' + host + '/' + aws_account_id + '/' + aws_queue_name;
        
        String canonical_request = Sqs.createCanonicalRequest();
        String string_to_sign = Sqs.createTheStringToSign(canonical_request);
        String signature = Sqs.calculateTheSignature(string_to_sign);
        String authorization_header = Sqs.addSigningInfoToTheRequest(signature);
        
        Sqs.sendRequest('POST', authorization_header, amz_date, request_parameters, endpoint);    
    }
    
    // TO DO public static void ReceiveMessage(String aws_region, String aws_account_id, String aws_queue_name, String message_body){}
    // TO DO public static void DeleteMessage(String aws_region, String aws_account_id, String aws_queue_name, String message_body){}
    
    public static void sendRequest(String method, String authorization_header, String amz_date, String request_parameters, String endpoint){
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        request.setHeader('Authorization', authorization_header);
        request.setHeader('x-amz-date', amz_date);
        // Set the body as a JSON object
        request.setBody(request_parameters);
        HttpResponse response = http.send(request);
        // Parse the JSON response
        if (response.getStatusCode() != 200) {
            System.debug('The status code returned was not expected: ' +
                         response.getStatusCode() + ' ' + response.getStatus() + ' ' + response.getBody());
        } else {
            System.debug(response.getBody());
        }
    }
    
    // ************* TASK 1: CREATE A CANONICAL REQUEST *************
    // http://docs.aws.amazon.com/general/latest/gr/sigv4-create-canonical-request.html
    private static String createCanonicalRequest() {
        
        String host = aws_service + '.' + aws_region + '.amazonaws.com';
        
        // Step 1 is to define the verb (GET, POST, etc.)
        String method = 'POST';
        
        // Step 2: Create canonical URI--the part of the URI from domain to query
        String canonical_uri = '/' + aws_account_id + '/' + aws_queue_name;
        
        // Step 3: Create the canonical query string. In this example, request
        // parameters are passed in the body of the request and the query string  is blank.
        String canonical_querystring = EncodingUtil.urlEncode('', 'UTF-8');
        
        // Step 4: Create the canonical headers. Header names must be trimmed
        // and lowercase, and sorted in code point order from low to high.
        // Note that there is a trailing \n
        String canonical_headers = 'content-type:' + content_type + '\n' + 'host:' + host + '\n' + 'x-amz-date:' + amz_date + '\n';
        
        // Step 5: Create the list of signed headers. This lists the headers
        // in the canonical_headers list, delimited with ";" and in alpha order.
        String signed_headers = 'content-type;host;x-amz-date';
        
        // Step 6: Create payload hash. In this example, the payload 
        // (body of the request) contains the request parameters.
        String payload_hash = hashlibSha256(request_parameters);
        
        // Step 7: Combine elements to create canonical request
        String canonical_request =
            method + '\n' +
            canonical_uri + '\n' +
            canonical_querystring + '\n' +
            canonical_headers + '\n' +
            signed_headers + '\n' +
            payload_hash;
        
        return canonical_request;
    }
    
    // ************* TASK 2: CREATE THE STRING TO SIGN*************
    private static String createTheStringToSign(String canonical_request) {
        // Match the algorithm to the hashing algorithm you use,
        // either SHA-1 or SHA-256 (recommended)
        String algorithm = 'AWS4-HMAC-SHA256';
        String credential_scope = date_stamp + '/' + aws_region + '/' + aws_service + '/' + 'aws4_request';
        String string_to_sign =
            algorithm + '\n' +
            amz_date + '\n' +
            credential_scope + '\n' +
            hashlibSha256(canonical_request);
        return string_to_sign;
    }
    
    // ************* TASK 3: CALCULATE THE SIGNATURE *************
    private static String calculateTheSignature(String string_to_sign) {
        // Create the signing key using the function defined above.
        Blob signing_key = getSignatureKey(secret_key, date_stamp, aws_region, aws_service);
        
        // Sign the string_to_sign using the signing_key
        String signature = EncodingUtil.convertToHex(Crypto.generateMac('HmacSHA256', Blob.valueof(string_to_sign), signing_key));
        return signature;
    }
    
    // ************* TASK 4: ADD SIGNING INFORMATION TO THE REQUEST *************
    private static String addSigningInfoToTheRequest(String signature) {
        String credential_scope = date_stamp + '/' + aws_region + '/' + aws_service + '/' + 'aws4_request';
        String signed_headers = 'content-type;host;x-amz-date';
        String algorithm = 'AWS4-HMAC-SHA256';
        // Put the signature information in a header named Authorization.
        String authorization_header = algorithm + ' ' + 'Credential=' + access_key + '/' + credential_scope + ', ' + 'SignedHeaders=' + signed_headers + ', ' + 'Signature=' + signature;
        return authorization_header;
    }
    private static Blob getSignatureKey(String key, String date_stamp, String region_name, String service_name) {
        Blob kDate = sign(date_stamp, Blob.valueof('AWS4' + key));
        Blob kRegion = sign(region_name, kDate);
        Blob kService = sign(service_name, kRegion);
        Blob kSigning = sign('aws4_request', kService);
        return kSigning;
    }
    private static Blob sign(String data, Blob key) {
        return Crypto.generateMac('HmacSHA256', Blob.valueOf(data), key);
    }
    private static String hashlibSha256(String message) {
        return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(message)));
    }
}
