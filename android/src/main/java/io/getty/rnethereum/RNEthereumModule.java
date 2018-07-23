
package io.getty.rnethereum;

import android.content.Context;
import android.util.Log;

import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.ReadableArray;

import org.spongycastle.util.encoders.*;

import io.github.novacrypto.bip39.MnemonicGenerator;
import io.github.novacrypto.bip39.MnemonicValidator;
import io.github.novacrypto.bip39.SeedCalculator;
import io.github.novacrypto.bip39.Words;
import io.github.novacrypto.bip39.wordlists.English;
import io.github.novacrypto.bip32.ExtendedPrivateKey;
import io.github.novacrypto.bip32.CKDpriv;
import io.github.novacrypto.bip32.Network;
import io.github.novacrypto.bip32.networks.Bitcoin;
import static io.github.novacrypto.bip32.Index.hard;
import io.github.novacrypto.bip39.Validation.*;

import org.web3j.protocol.Web3j;
import org.web3j.protocol.Web3jFactory;
import org.web3j.protocol.http.HttpService;
import org.web3j.protocol.core.DefaultBlockParameterName;
import org.web3j.protocol.core.methods.response.EthSendTransaction;
import org.web3j.protocol.core.methods.response.EthGasPrice;
import org.web3j.protocol.core.methods.response.EthGetTransactionCount;
import org.web3j.crypto.ECKeyPair;
import org.web3j.crypto.Keys;
import org.web3j.crypto.Sign;
import org.web3j.crypto.Credentials;
import org.web3j.crypto.RawTransaction;
import org.web3j.crypto.TransactionDecoder;
import org.web3j.crypto.TransactionEncoder;
import org.web3j.utils.Convert;
import org.web3j.utils.Numeric;

import java.security.SecureRandom;
import java.math.BigInteger;
import java.util.*;
import java.lang.*;

public class RNEthereumModule extends ReactContextBaseJavaModule {

  private final ReactApplicationContext reactContext;
  private String _nodeUrl = "http://localhost:8545";

  public RNEthereumModule(ReactApplicationContext reactContext) {
    super(reactContext);
    this.reactContext = reactContext;
  }

  @Override
  public String getName() {
    return "RNEthereum";
  }

  @ReactMethod
  public void setNodeUrl(final String nodeUrl, final Promise promise)
  {
    new Thread(new Runnable()
    {
      public void run()
      {
        try
        {
          //Set node node url
          _nodeUrl = nodeUrl;

          //Return true
          promise.resolve(true);
        }
        catch(Exception e)
        {
          //Exception, reject
          promise.reject("Failed to set node url", "Native exception thrown", e);
        }
      }
    }).start();
  }

  @ReactMethod
  public void generateKeypair(final String mnemonics,
                              final int vaultNumber,
                              final Promise promise)
  {
    new Thread(new Runnable()
    {
      public void run()
      {
        try
        {
          //Create ECKey from mnemonics seed
          byte[] mnemonicSeedBytes = new SeedCalculator().calculateSeed(mnemonics, "");

          //Derive private key
          ExtendedPrivateKey rootKey = ExtendedPrivateKey.fromSeed(mnemonicSeedBytes, Bitcoin.MAIN_NET);
          byte[] derivedKeyBytes = rootKey
                  .cKDpriv(hard(44))
                  .cKDpriv(hard(60))
                  .cKDpriv(hard(vaultNumber))
                  .cKDpriv(0)
                  .cKDpriv(0)
                  .extendedKeyByteArray();

          int keyOffset = derivedKeyBytes.length - 36;
          byte[] privateKeyBytes = Arrays.copyOfRange(derivedKeyBytes, keyOffset, keyOffset + 32);
          ECKeyPair keyPair = ECKeyPair.create(privateKeyBytes);

          //Get public address
          String plainAddress = Keys.getAddress(keyPair);
          String address = Keys.toChecksumAddress(plainAddress);

          //Get private key
          String privateKey = StringUtils.ByteArrayToHexString(privateKeyBytes).toUpperCase();

          //Get public key
          byte[] publicKeyBytes = keyPair.getPublicKey().toByteArray();
          String publicKey = StringUtils.ByteArrayToHexString(publicKeyBytes).toUpperCase();

          //Get password
          String password = new String(org.spongycastle.util.encoders.Base64.encode(privateKeyBytes));

          //Create generated account map
          WritableMap returnGeneratedAccount = Arguments.createMap();
          returnGeneratedAccount.putString("address", address);
          returnGeneratedAccount.putString("privateKey", privateKey);
          returnGeneratedAccount.putString("publicKey", publicKey);
          returnGeneratedAccount.putString("password", password);

          //Return generated account map
          promise.resolve(returnGeneratedAccount);
        }
        catch(Exception e)
        {
          //Exception, reject
          promise.reject("Failed to generate account", "Native exception thrown", e);
        }
      }
    }).start();
  }

  @ReactMethod
  public void decodeTransaction(final String encodedTransaction, final Promise promise)
  {
    new Thread(new Runnable()
    {
      public void run()
      {
        try
        {
          //Parse from hex encoded transaction
          RawTransaction transaction = TransactionDecoder.decode(encodedTransaction);
          if(transaction == null)
          {
            //Problem creating transaction, reject and return
            promise.reject("Failed to decode transaction", "Decoder/parser error", null);
            return;
          }

          //Create decoded transaction map
          WritableMap returnDecodedTransaction = Arguments.createMap();
          returnDecodedTransaction.putInt("nonce", transaction.getNonce().intValue());
          returnDecodedTransaction.putString("gasPrice", transaction.getGasPrice().toString());
          returnDecodedTransaction.putString("gasLimit", transaction.getGasLimit().toString());
          returnDecodedTransaction.putString("toAddress", transaction.getTo());
          returnDecodedTransaction.putString("value", transaction.getValue().toString());

          //Return result
          promise.resolve(returnDecodedTransaction);
        }
        catch(Exception e)
        {
          //Exception, reject
          promise.reject("Failed to decode transaction", "Native exception thrown", e);
        }
      }
    }).start();
  }

  @ReactMethod
  public void createTransferTransaction(final String fromAddress, final String toAddress, final double amount, final Promise promise)
  {
    new Thread(new Runnable()
    {
      public void run()
      {
        try
        {
          //Create web3j instance
          Web3j web3 = Web3jFactory.build(new HttpService(_nodeUrl));

          //Get gas price
          EthGasPrice ethGasPrice = web3.ethGasPrice().send();
          if(ethGasPrice.hasError())
          {
            //Reject and return
            promise.reject("Failed to create transfer transaction", "Get gas price error", null);
            return;
          }
          BigInteger gasPrice = ethGasPrice.getGasPrice();
          BigInteger gasLimit = BigInteger.valueOf(21000L);

          //Get nonce (transaction count)
          EthGetTransactionCount ethGetTransactionCount = web3.ethGetTransactionCount(fromAddress, DefaultBlockParameterName.LATEST).send();
          if(ethGetTransactionCount.hasError())
          {
            //Reject and return
            promise.reject("Failed to create transfer transaction", "Get transaction count error", null);
            return;
          }
          BigInteger nonce = ethGetTransactionCount.getTransactionCount();

          //Convert amount to transaction value and create transaction
          BigInteger value = Convert.toWei(Double.toString(amount), Convert.Unit.ETHER).toBigInteger();

          //Create transaction
          RawTransaction transaction = RawTransaction.createEtherTransaction(nonce, gasPrice, gasLimit, toAddress, value);

          //Serialize transaction and get hex encoded string
          byte[] unsignedTransactionBytes = TransactionEncoder.encode(transaction);
          String encodedUnsignedTransaction = StringUtils.ByteArrayToHexString(unsignedTransactionBytes).toUpperCase();

          //Return result
          promise.resolve(encodedUnsignedTransaction);
        }
        catch(Exception e)
        {
          //Exception, reject
          promise.reject("Failed to create transfer transaction", "Native exception thrown", e);
        }
      }
    }).start();
  }

  @ReactMethod
  public void signTransaction(final String ownerPrivateKey, final String encodedTransaction, final Promise promise)
  {
    new Thread(new Runnable()
    {
      public void run()
      {
        try
        {
          //Get key and credentials
          byte[] ownerPrivateKeyBytes = StringUtils.HexStringToByteArray(ownerPrivateKey);
          ECKeyPair keyPair = ECKeyPair.create(ownerPrivateKeyBytes);
          Credentials credentials = Credentials.create(keyPair);

          //Parse from hex encoded transaction
          RawTransaction transaction = TransactionDecoder.decode(encodedTransaction);
          if(transaction == null)
          {
            //Problem creating transaction, reject and return
            promise.reject("Failed to sign transaction", "Decoder/parser error", null);
            return;
          }

          //Sign transaction and get hex encoded string
          byte[] signedTransactionBytes = TransactionEncoder.signMessage(transaction, credentials);
          String encodedSignedTransaction = StringUtils.ByteArrayToHexString(signedTransactionBytes).toUpperCase();

          //Return result
          promise.resolve(encodedSignedTransaction);
        }
        catch(Exception e)
        {
          //Exception, reject
          promise.reject("Failed to sign transaction", "Native exception thrown", e);
        }
      }
    }).start();
  }

  @ReactMethod
  public void sendTransaction(final String encodedTransaction, final Promise promise)
  {
    new Thread(new Runnable()
    {
      public void run()
      {
        try
        {
          //Add hex prefix to encoded transaction if missing
          String transaction = encodedTransaction;
          if(!transaction.startsWith("0x"))
          { transaction = "0x" + transaction; }

          //Create web3j instance, send the transaction
          Web3j web3 = Web3jFactory.build(new HttpService(_nodeUrl));
          EthSendTransaction ethSendTransaction = web3.ethSendRawTransaction(transaction).send();

          //There was a problem sending the transaction
          if(ethSendTransaction.hasError())
          {
            //Reject and return
            promise.reject("Failed to send transaction", "Send transaction error", null);
            return;
          }

          //Get transaction hash and return result
          String transactionHash = ethSendTransaction.getTransactionHash();
          promise.resolve(transactionHash);
        }
        catch(Exception e)
        {
          //Exception, reject
          promise.reject("Failed to sign transaction", "Native exception thrown", e);
        }
      }
    }).start();
  }
}
