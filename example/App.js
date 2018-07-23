import React, { Component } from 'react';
import {
  Platform,
  StyleSheet,
  Text,
  View,
  TextInput,
  ScrollView,
  Button,
  ActivityIndicator
} from 'react-native';
import RNEthereum from 'react-native-ethereum';

export default class App extends Component {
  constructor() {
    super();

    this.state = {
      address: null,
      privateKey: null,
      publicKey: null,
      password: null,
      mnemonics: "hub purpose pistol mountain tape possible aware board decorate good chair only",
      recvAddress: null,
      transactionHash: null,
      sending: false
    }
  }

  async componentDidMount() {

    await RNEthereum.setNodeUrl("https://ropsten.infura.io/cW3HRlcsT9FuNkwBJmeo");

    var generatedKeypair = await RNEthereum.generateKeypair(this.state.mnemonics, 0);
    var generatedRecvKeypair = await RNEthereum.generateKeypair(this.state.mnemonics, 1);

    this.setState({
      address: generatedKeypair.address,
      privateKey: generatedKeypair.privateKey,
      publicKey: generatedKeypair.publicKey,
      password: generatedKeypair.password,
      recvAddress: generatedRecvKeypair.address
    });
  }

  async onSendTapped()
  {
    this.setState({ sending: true, transactionHash: null });
    var unsignedTransaction = await RNEthereum.createTransferTransaction(this.state.address,
                                                                         this.state.recvAddress,
                                                                         0.001);
    var signedTransaction = await RNEthereum.signTransaction(this.state.privateKey, unsignedTransaction);
    var transactionHash = await RNEthereum.sendTransaction(signedTransaction);
    this.setState({ sending: false, transactionHash: transactionHash });
  }

  render() {
    return (
      <ScrollView>
        <View style={styles.container}>
          <Text style={styles.title}>
            Generated Ethereum Account
          </Text>
          <Text style={styles.subtitle}>From Mnemonics</Text>
          <TextInput style={styles.value} multiline={true}>{ this.state.mnemonics }</TextInput>
          <Text style={styles.subtitle}>Address</Text>
          <TextInput style={styles.value} multiline={true}>{ this.state.address }</TextInput>
          <Text style={styles.subtitle}>Private Key</Text>
          <TextInput style={styles.value} multiline={true}>{ this.state.privateKey }</TextInput>
          <Text style={styles.subtitle}>Public Key</Text>
          <TextInput style={styles.value} multiline={true}>{ this.state.publicKey }</TextInput>
          <Text style={styles.subtitle}>Password</Text>
          <TextInput style={styles.value} multiline={true}>{ this.state.password }</TextInput>
          <Button
            onPress={this.onSendTapped.bind(this)}
            disabled={this.state.sending}
            title={"Send 0.001 to " + this.state.recvAddress}
            color="#841584"/>
          <Text style={styles.subtitle}>Transaction Hash</Text>
          {
            (this.state.transactionHash != null) ?
            (<TextInput style={styles.value} multiline={true}>{this.state.transactionHash}</TextInput>) :
            (<ActivityIndicator style={styles.spinner} animating={this.state.sending} size="small" color="#841584"/>)
          }
        </View>
      </ScrollView>
    );
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    margin: 10
  },
  title: {
    fontSize: 20,
    fontWeight: 'bold',
    textAlign: 'center',
    marginTop: 20,
    marginBottom: 10
  },
  subtitle: {
    fontSize: 16,
    fontWeight: 'bold',
    textAlign: 'center',
    marginTop: 10,
  },
  value: {
    fontSize: 12,
    textAlign: 'center',
  },
  spinner: {
    marginTop: 5
  }
});
