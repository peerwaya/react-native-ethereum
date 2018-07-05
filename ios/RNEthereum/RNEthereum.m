#import "RNEthereum.h"

#import "NSData+FastHex.h"

#import "JsonRpcProvider.h"
#import "Account.h"
#import "Transaction.h"

@implementation RNEthereum

RCT_EXPORT_MODULE();

#pragma mark -
#pragma mark Creation + Destruction
#pragma mark

- (id) init
{
    if (self = [super init])
    {
        _nodeUrl = @"http://localhost:8545";
    }
    return self;
}

#pragma mark -
#pragma mark Super Overrides
#pragma mark

- (dispatch_queue_t) methodQueue
{ return dispatch_get_main_queue(); }

+ (BOOL) requiresMainQueueSetup
{ return NO; }

#pragma mark -
#pragma mark Public Native Methods
#pragma mark

RCT_REMAP_METHOD(setNodeUrl,
                 nodeUrl:(NSString *)nodeUrl
                 setNodeUrlResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    @try
    {
        //Set node url
        _nodeUrl = nodeUrl;
        
        //Return true
        resolve(@(true));
    }
    @catch(NSException *e)
    {
        //Exception, reject
        NSDictionary *userInfo = @{ @"name": e.name, @"reason": e.reason };
        NSError *error = [NSError errorWithDomain: @"io.getty.rnethereum" code: 0 userInfo: userInfo];
        reject(@"Failed to set node url", @"Native exception thrown", error);
    }
}

RCT_REMAP_METHOD(generateKeypair,
                 mnemonics:(NSString *)mnemonics
                 vaultNumber:(NSNumber * _Nonnull)vaultNumber
                 generateAccountWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    @try
    {
        if(![Account isValidMnemonicPhrase: mnemonics])
        {
            //Mnemonics are invalid, reject and return
            reject(@"Failed to restore account from mnemonics", @"Mnemonics invalid", nil);
            return;
        }
        
        //Create ethereum account for mnemonics and vault number
        Account *account = [Account accountWithMnemonicPhrase: mnemonics
                                                accountNumber: vaultNumber.intValue];
        
        //Get password using base64 encoded private key data
        NSString *password = [account.privateKey base64EncodedStringWithOptions: NSDataBase64Encoding64CharacterLineLength];
        
        //Get hex encoded private & public keys
        NSString *privateKey = [account.privateKey hexStringRepresentationUppercase: YES];
        NSString *publicKey = [account.publicKey hexStringRepresentationUppercase: YES];
        
        //Create generated account dictionary
        NSDictionary *returnGeneratedAccount =
        @{
            @"address": account.address.checksumAddress,
            @"privateKey": privateKey,
            @"publicKey": publicKey,
            @"password": password
        };
        
        //Return the restored account dictionary
        resolve(returnGeneratedAccount);
    }
    @catch(NSException *e)
    {
	//Exception, reject
        NSDictionary *userInfo = @{ @"name": e.name, @"reason": e.reason };
        NSError *error = [NSError errorWithDomain: @"io.getty.rnethereum" code: 0 userInfo: userInfo];
        reject(@"Failed to generate keypair from mnemonics", @"Native exception thrown", error);
    }
}

RCT_REMAP_METHOD(signTransaction,
                 ownerPrivateKey: (NSString *) ownerPrivateKey
                 encodedTransaction:(NSString *)encodedTransaction
                 signTransactionWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    @try
    {
        //Create ethereum account for private key
        NSData *privateKeyBytes = [NSData dataWithHexString: ownerPrivateKey];
        Account *account = [Account accountWithPrivateKey: privateKeyBytes];

        //Decode hex encoded string to data
        NSData *transactionData = [NSData dataWithHexString: encodedTransaction];
        
        //Attempt to parse transaction from data
        Transaction *transaction = [Transaction transactionWithData: transactionData];
        if(!transaction)
        {
            //Problem decoding/parsing transaction, reject and return
            reject(@"Failed to sign transaction", @"Decoder/parser error", nil);
            return;
        }
        
        //Sign transaction
        [account sign: transaction];
        
        //Get hex encoded string of signed transaction
        NSData *signedTransactionData = [transaction serialize];
        NSString *encodedSignedTransaction = [signedTransactionData hexStringRepresentationUppercase: YES];
        
        //Return result
        resolve(encodedSignedTransaction);
    }
    @catch(NSException *e)
    {
        //Exception, reject
        NSDictionary *userInfo = @{ @"name": e.name, @"reason": e.reason };
        NSError *error = [NSError errorWithDomain: @"io.getty.rnethereum" code: 0 userInfo: userInfo];
        reject(@"Failed to sign transaction", @"Native exception thrown", error);
    }
}

RCT_REMAP_METHOD(sendTransaction,
                 encodedTransaction:(NSString *)encodedTransaction
                 sendTransactionWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    @try
    {
        //Decode hex encoded string to data
        NSData *transactionData = [NSData dataWithHexString: encodedTransaction];
        
        //Send transaction data
        JsonRpcProvider *provider = [[JsonRpcProvider alloc] initWithChainId: ChainIdAny url: [NSURL URLWithString: _nodeUrl]];
        [[provider sendTransaction: transactionData] onCompletion:^(HashPromise *promise)
        {
            //There was a problem sending the transaction
            if(promise.error)
            {
                //Reject and return
                reject(@"Failed to send transaction", @"Send transaction error", nil);
                return;
            }
            
            //Get transaction hash and return result
            NSString *transactionHash = promise.value.hexString;
            resolve(transactionHash);
        }];
    }
    @catch(NSException *e)
    {
        //Exception, reject
        NSDictionary *userInfo = @{ @"name": e.name, @"reason": e.reason };
        NSError *error = [NSError errorWithDomain: @"io.getty.rnethereum" code: 0 userInfo: userInfo];
        reject(@"Failed to send transaction", @"Native exception thrown", error);
    }
}

@end
