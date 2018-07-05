package org.web3j.crypto;

import java.math.BigInteger;

import org.web3j.crypto.*;
import org.web3j.rlp.RlpDecoder;
import org.web3j.rlp.RlpList;
import org.web3j.rlp.RlpString;
import org.web3j.utils.Numeric;

public class TransactionDecoder {

    public static RawTransaction decode(String hexTransaction) {
        byte[] transaction = Numeric.hexStringToByteArray(hexTransaction);
        RlpList rlpList = RlpDecoder.decode(transaction);
        RlpList values = (RlpList) rlpList.getValues().get(0);
        BigInteger nonce = new BigInteger(((RlpString) values.getValues().get(0)).getBytes());
        BigInteger gasPrice = new BigInteger(((RlpString) values.getValues().get(1)).getBytes());
        BigInteger gasLimit = new BigInteger(((RlpString) values.getValues().get(2)).getBytes());
        String to = Numeric.toHexString(((RlpString) values.getValues().get(3)).getBytes());
        BigInteger value = new BigInteger(((RlpString) values.getValues().get(4)).getBytes());
        String data = Numeric.toHexString(((RlpString) values.getValues().get(5)).getBytes());
        return RawTransaction.createTransaction(nonce, gasPrice, gasLimit, to, value, data);
    }

    private static byte[] zeroPadded(byte[] value, int size) {
        if (value.length == size) {
            return value;
        }
        int diff = size - value.length;
        byte[] paddedValue = new byte[size];
        System.arraycopy(value, 0, paddedValue, diff, value.length);
        return paddedValue;
    }
}
