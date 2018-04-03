﻿// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.


namespace Microsoft.Quantum.Canon
{
    open Microsoft.Quantum.Primitive;
    open Microsoft.Quantum.Extensions.Math;

    /// # Summary
    /// Multiply-controlled unitary operation $U$ that performs rotations
    /// by angle $\theta_j$ about single-qubit Pauli operator $P$ when 
    /// controlled by the $n$-qubit number state $\ket{j}$.
    ///
    /// $U = \sum^{2^n-1}_{j=0}\ket{j}\bra{j}\otimes e^{i P \theta_j}$.
    ///
    /// # Input
    /// ## coefficients
    /// Array of up to $2^n$ coefficients $\theta_j$. The $j$th coefficient 
    /// indexes the number state $\ket{j}$ encoded in big-endian format. 
    ///
    /// ## pauli
    /// Pauli operator $P$ that determines axis of rotation.
    ///
    /// ## control
    /// $n$-qubit control register that encodes number states $\ket{j}$ in
    /// big-endian format.
    ///
    /// ## target
    /// Single qubit register that is rotated by $e^{i P \theta_j}$.
    ///
    /// # Remarks
    /// `coefficients` will be padded with elements $\theta_j = 0.0$ if 
    /// fewer than $2^n$ are specified.
    operation MultiplexorPauli(coefficients:Double[], pauli: Pauli, control: BigEndian, target: Qubit) : (){
        body{
            if(pauli == PauliZ){
                let op = MultiplexorZ(coefficients, control, _);
                op(target);
            }
            elif(pauli == PauliX){
                let op = MultiplexorPauli(coefficients, PauliZ, control, _);
                WithCA(H, op, target);
            }
            elif(pauli == PauliY){
                let op = MultiplexorPauli(coefficients, PauliX, control, _);
                WithCA(Adjoint S, op, target);
            }
            elif(pauli == PauliI){
                DiagonalUnitary(coefficients, control);
            }
            else{
                fail $"MultiplexorPauli failed. Invalid pauli {pauli}.";
            }
        }
        adjoint auto
        controlled auto
        adjoint controlled auto
    }

    /// # Summary
    /// Multiply-controlled unitary operation $U$ that performs rotations
    /// by angle $\theta_j$ about single-qubit Pauli operator $Z$ when 
    /// controlled by $n$-qubit number state $\ket{j}$.
    ///
    /// $U = \sum^{2^n-1}_{j=0}\ket{j}\bra{j}\otimes e^{i Z \theta_j}$.
    ///
    /// # Input
    /// ## coefficients
    /// Array of up to $2^n$ coefficients $\theta_j$. The $j$th coefficient 
    /// indexes the number state $\ket{j}$ encoded in big-endian format. 
    ///
    /// ## control
    /// $n$-qubit control register that encodes number states $\ket{j}$ in
    /// big-endian format.
    ///
    /// ## target
    /// Single qubit register that is rotated by $e^{i P \theta_j}$.
    ///
    /// # Remarks
    /// `coefficients` will be padded with elements $\theta_j = 0.0$ if 
    /// fewer than $2^n$ are specified.
    ///
    /// # References
    /// - Synthesis of Quantum Logic Circuits
    ///   Vivek V. Shende, Stephen S. Bullock, Igor L. Markov
    ///   https://arxiv.org/abs/quant-ph/0406176
    operation MultiplexorZ(coefficients: Double[], control: BigEndian, target: Qubit) : () {
        body{
            // pad coefficients length to a power of 2.
            let maxCoefficients = 2^(Length(control));
            let padZeros = new Double[maxCoefficients - Length(coefficients)];
            
            if(maxCoefficients == 1){
                // Termination case
                Exp([PauliZ], coefficients[0], [target]);
            }
            else{
                // Compute new coefficients.
                let (coefficients0, coefficients1) = MultiplexorZComputeCoefficients_(coefficients + padZeros);
                MultiplexorZ(coefficients0, BigEndian(control[1..Length(control)-1]), target);
                CNOT(control[0], target);
                MultiplexorZ(coefficients1, BigEndian(control[1..Length(control)-1]), target);
                CNOT(control[0], target);
            }
        }
        adjoint auto
        controlled (controlRegister) {
            // pad coefficients length to a power of 2.
            let maxCoefficients = 2^(Length(control));
            let padZeros = new Double[maxCoefficients - Length(coefficients)];

            let controlZeros = new Double[maxCoefficients];
            let (coefficients0, coefficients1) = MultiplexorZComputeCoefficients_(controlZeros+coefficients+padZeros);
            
            MultiplexorZ(coefficients0, control, target);
            (Controlled X)(controlRegister, target);
            MultiplexorZ(coefficients1, control, target);
            (Controlled X)(controlRegister, target);
        }
        adjoint controlled auto
    }

    /// # Summary
    /// Diagonal unitary operation $U$ that applies a complex phase 
    /// $e^{i \theta_j}$ on the $n$-qubit number state $\ket{j}$.
    ///
    /// $U = \sum^{2^n-1}_{j=0}e^{i\theta_j}\ket{j}\bra{j}$.
    ///
    /// # Input
    /// ## coefficients
    /// Array of up to $2^n$ coefficients $\theta_j$. The $j$th coefficient 
    /// indexes the number state $\ket{j}$ encoded in big-endian format. 
    ///
    /// ## control
    /// $n$-qubit control register that encodes number states $\ket{j}$ in
    /// big-endian format.
    ///
    /// # Remarks
    /// `coefficients` will be padded with elements $\theta_j = 0.0$ if 
    /// fewer than $2^n$ are specified.
    ///
    /// # References
    /// - Synthesis of Quantum Logic Circuits
    ///   Vivek V. Shende, Stephen S. Bullock, Igor L. Markov
    ///   https://arxiv.org/abs/quant-ph/0406176
    operation DiagonalUnitary(coefficients: Double[], qubits: BigEndian) : () {
        body{
            if(Length(qubits) == 0){
                fail $"operation DiagonalUnitary -- Number of qubits must be greater than 0.";
            }

            // pad coefficients length to a power of 2.
            let maxCoefficients = 2^(Length(qubits));
            let padZeros = new Double[maxCoefficients - Length(coefficients)];
            
            // Compute new coefficients.
            let (coefficients0, coefficients1) = MultiplexorZComputeCoefficients_(coefficients + padZeros);
            MultiplexorZ(coefficients1, BigEndian(qubits[1..Length(qubits)-1]), qubits[0]);            
            if(maxCoefficients == 2){
                // Termination case
                Exp([PauliI], 1.0 * coefficients0[0], qubits);
            }
            else{
                DiagonalUnitary(coefficients0, BigEndian(qubits[1..Length(qubits)-1]));
            }
        }
        adjoint auto
        controlled auto
        adjoint controlled auto
    }

    /// # Summary
    /// Implementation step of multiply-controlled Z rotations.
    /// # See Also
    /// - Microsoft.Quantum.Canon.MultiplexorZ
    function MultiplexorZComputeCoefficients_(coefficients: Double[]) : (Double[], Double[]) {
        let newCoefficientsLength = Length(coefficients)/2;
        mutable coefficients0 = new Double[newCoefficientsLength];
        mutable coefficients1 = new Double[newCoefficientsLength];
        for(idxCoeff in 0..newCoefficientsLength-1){
            set coefficients0[idxCoeff] = 0.5 * (coefficients[idxCoeff] + coefficients[idxCoeff + newCoefficientsLength]);
            set coefficients1[idxCoeff] = 0.5 * (coefficients[idxCoeff] - coefficients[idxCoeff + newCoefficientsLength]);
        }
        return (coefficients0, coefficients1);
    }

    
    /// # Summary
    /// Multiply-controlled unitary operation $U$ that applies a unitary $V_j$ 
    /// when controlled by $n$-qubit number state $\ket{j}$.
    ///
    /// $U = \sum^{2^n-1}_{j=0}\ket{j}\bra{j}\otimes V_j$.
    ///
    /// # Input
    /// ## unitaries
    /// Array of up to $2^n$ unitary operations. The $j$th operation 
    /// is indexed by the number state $\ket{j}$ encoded in big-endian format. 
    ///
    /// ## index
    /// $n$-qubit control register that encodes number states $\ket{j}$ in
    /// big-endian format.
    ///
    /// ## target
    /// Generic qubit register that $V_j$ acts on.
    ///
    /// # Remarks
    /// `coefficients` will be padded with identity elements if 
    /// fewer than $2^n$ are specified. This implementation uses
    /// $n-1$ ancilla qubits.
    ///
    /// # References
    /// - Toward the first quantum simulation with quantum speedup
    ///   Andrew M. Childs, Dmitri Maslov, Yunseong Nam, Neil J. Ross, Yuan Su
    ///   https://arxiv.org/abs/1711.10980
    operation MultiplexorUnitary<'T>(unitaries : ('T => () : Adjoint, Controlled)[], index: BigEndian, target: 'T) : () {
        body{
            if(Length(index) == 0){
                fail "MultiplexorUnitary failed. Number of index qubits must be greater than 0.";
            }
            if(Length(unitaries) > 0){
                let ancilla = new Qubit[0];
                MultiplexorUnitary_(unitaries, ancilla, index, target);
            }
        }
        adjoint auto
        controlled auto
        adjoint controlled auto
    }

    /// # Summary
    /// Implementation step of MultiplexorUnitary.
    /// # See Also
    /// - Microsoft.Quantum.Canon.MultiplexorUnitary
    operation MultiplexorUnitary_<'T>(unitaries : ('T => () : Adjoint, Controlled)[], ancilla: Qubit[], index: BigEndian, target: 'T) : () {
        body{
            let nIndex = Length(index);
            let nStates = 2^nIndex;
            let nUnitaries = Length(unitaries);
            
            let nUnitariesRight = MinI(nUnitaries, nStates/2);
            let nUnitariesLeft = MinI(nUnitaries, nStates);

            let rightUnitaries = unitaries[0..(nUnitariesRight -1)];
            let leftUnitaries = unitaries[nUnitariesRight..nUnitariesLeft - 1];
            let newControls = BigEndian(index[1..nIndex-1]);

            if(nUnitaries > 0){
                if(Length(ancilla) == 1 && nIndex==0){
                    // Termination case
                    (Controlled unitaries[0])(ancilla, target);
                }
                elif(Length(ancilla) == 0 && nIndex>=1){
                    // Start case
                    let newAncilla = [index[0]];
                    if(nUnitariesLeft > 0){
                        MultiplexorUnitary_(leftUnitaries, newAncilla, newControls, target);
                    }
                    X(newAncilla[0]);
                    MultiplexorUnitary_(rightUnitaries, newAncilla, newControls, target);
                    X(newAncilla[0]);
                }
                else{
                    // Recursion that reduces nIndex by 1 & sets Length(ancilla) to 1.
                    using(newAncilla = Qubit[1]){
                        (Controlled X)(ancilla + [index[0]], newAncilla[0]);
                        if(nUnitariesLeft > 0){
                            MultiplexorUnitary_(leftUnitaries, newAncilla, newControls, target);
                        }
                        (Controlled X)(ancilla, newAncilla[0]);
                        MultiplexorUnitary_(rightUnitaries, newAncilla, newControls, target);
                        (Controlled X)(ancilla, newAncilla[0]);
                        (Controlled X)(ancilla + [index[0]], newAncilla[0]);
                    }
                }
            }
        }
        adjoint auto
        controlled (controlRegister) {
            MultiplexorUnitary_(unitaries, controlRegister, index, target);
        }
        adjoint controlled auto
    }
    
}