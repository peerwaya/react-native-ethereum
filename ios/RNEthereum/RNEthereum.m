#import "RNEthereum.h"

#import "NSData+FastHex.h"

#import "JsonRpcProvider.h"
#import "Account.h"
#import "Transaction.h"

#define kRNEthereumWeiUnit  1000000000000000000

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

+ (BOOL) requiresMainQueueSetup
{ return NO; }

#pragma mark -
#pragma mark Private Methods
#pragma mark

- (BigNumber * _Nullable) _getGasPrice
{
    //Declare variables
    __block BigNumber * _Nullable gasPrice = nil;
    
    //Attempt to get the gas price
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    JsonRpcProvider *provider = [[JsonRpcProvider alloc] initWithChainId: ChainIdAny url: [NSURL URLWithString: _nodeUrl]];
    [[provider getGasPrice] onCompletion:^(BigNumberPromise *promise)
    {
         //If no errors, set gas price
         if(!promise.error)
         { gasPrice = promise.value; }
        
        //Signal that get gas price is finished
        dispatch_semaphore_signal(sema);
    }];
    
    //Wait for get gas price to finish
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    
    //Return gas price
    return gasPrice;
}

- (NSInteger) _getTransactionCountForAddress: (Address *) address
{
    //Declare variables
    __block NSInteger transactionCount = -1;
    
    //Attempt to get transaction count for address
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    JsonRpcProvider *provider = [[JsonRpcProvider alloc] initWithChainId: ChainIdAny url: [NSURL URLWithString: _nodeUrl]];
    [[provider getTransactionCount: address blockTag: BLOCK_TAG_PENDING] onCompletion:^(IntegerPromise *promise)
    {
        //If no errors, set transaction count
        if(!promise.error)
        { transactionCount = promise.value; }
        
        //Signal that get transaction count is finished
        dispatch_semaphore_signal(sema);
    }];
    
    //Wait for get transaction count to finish
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    
    //Return gas price
    return transactionCount;
}

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

RCT_REMAP_METHOD(decodeTransaction,
                 encodedTransaction:(NSString *)encodedTransaction
                 decodeTransactionWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    @try
    {
        //Decode hex encoded string to data
        NSData *transactionData = [NSData dataWithHexString: encodedTransaction];
        
        //Attempt to parse transaction from data
        Transaction *transaction = [Transaction transactionWithData: transactionData];
        if(!transaction)
        {
            //Problem decoding/parsing transaction, reject and return
            reject(@"Failed to decode transaction", @"Decoder/parser error", nil);
            return;
        }
        
        //Create decoded transaction dictionary
        NSDictionary *returnDecodedTransaction =
        @{
            @"nonce": @(transaction.nonce),
            @"gasPrice": transaction.gasPrice.decimalString,
            @"gasLimit": transaction.gasLimit.decimalString,
            @"toAddress": transaction.toAddress.checksumAddress,
            @"value": transaction.value.decimalString
        };
        
        //Return result
        resolve(returnDecodedTransaction);
    }
    @catch(NSException *e)
    {
        //Exception, reject
        NSDictionary *userInfo = @{ @"name": e.name, @"reason": e.reason };
        NSError *error = [NSError errorWithDomain: @"io.getty.rnethereum" code: 0 userInfo: userInfo];
        reject(@"Failed to decode transaction", @"Native exception thrown", error);
    }
}

RCT_REMAP_METHOD(createTransferTransaction,
                 fromAddress: (NSString *)fromAddress
                 toAddress:(NSString *)toAddress
                 amount:(NSNumber * _Nonnull)amount
                 createTransferTransactionWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    @try
    {
        //Attempt to get gas price
        BigNumber *gasPrice = [self _getGasPrice];
        if(!gasPrice)
        {
            //Problem getting gas price, reject and return
            reject(@"Failed to get gas price", @"Connection error", nil);
            return;
        }
        
        //Attempt to get nonce (last transaction count)
        NSInteger nonce = [self _getTransactionCountForAddress: [Address addressWithString: fromAddress]];
        if(nonce < 0)
        {
            //Problem getting last transaction count, reject and return
            reject(@"Failed to get last transaction count", @"Connection error", nil);
            return;
        }
        
        //Convert floating point amount to transaction value
        NSInteger amountValue = amount.doubleValue * kRNEthereumWeiUnit;
        
        //Create transaction
        Transaction *transaction = [Transaction transaction];
        transaction.nonce = nonce;
        transaction.gasPrice = gasPrice;
        transaction.gasLimit = [BigNumber bigNumberWithInteger: 21000];
        transaction.toAddress = [Address addressWithString: toAddress];
        transaction.value = [BigNumber bigNumberWithInteger: amountValue];
        
        //Get hex encoded string of signed transaction
        NSData *unsignedTransactionData = [transaction serialize];
        NSString *encodedUnsignedTransaction = [unsignedTransactionData hexStringRepresentationUppercase: YES];
        
        //Return result
        resolve(encodedUnsignedTransaction);
    }
    @catch(NSException *e)
    {
        //Exception, reject
        NSDictionary *userInfo = @{ @"name": e.name, @"reason": e.reason };
        NSError *error = [NSError errorWithDomain: @"io.getty.rnethereum" code: 0 userInfo: userInfo];
        reject(@"Failed to create transfer transaction", @"Native exception thrown", error);
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
