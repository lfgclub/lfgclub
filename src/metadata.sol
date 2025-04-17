// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

library Metadata {

    function combineInputs(
        string memory str0,
        string memory str1,
        string memory str2,
        string memory str3,
        string memory str4,
        string memory str5,
        string memory str6,
        uint256 number
    ) public pure returns (string memory) {
        return string(
            abi.encodePacked(
                "ID:",
                uintToString(number),
                "|Name:",
                str0,
                "|Symbol:",
                str1,
                "|Description:",
                str2,
                "|Image:",
                str3,
                "|Web:",
                str4,
                "|X:",
                str5,
                "|Telegram:",
                str6
            )
        );
    }

    function calculateHash(uint256 nmbr, string[7] memory input) public pure returns (bytes32 hash) {
        string memory tempVal = combineInputs(input[0], input[1], input[2], input[0], input[1], input[2], input[3], nmbr);
        hash = keccak256(abi.encode(tempVal));
    }

    function uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }

        uint256 temp = value;
        uint256 digits;

        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + value % 10));
            value /= 10;
        }

        return string(buffer);
    }

    /// @dev Base58 alphabet used by IPFS for CIDv0
    bytes constant ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

    /**
     * @notice Convert a 32-byte SHA-256 digest into an IPFS CIDv0 (Qm...) string
     * @param _digest The raw 32-byte SHA-256 hash
     * @return The CIDv0 string, e.g. "QmYwAPJz..."
     */
    function toBase58CIDv0(bytes32 _digest) public pure returns (string memory) {
        // 1) Prepend multihash prefix 0x12 0x20 (type=SHA-256, length=32)
        //    So now we have 34 bytes: [0x12, 0x20, digest...]
        bytes memory input = abi.encodePacked(hex"1220", _digest); // length = 34

        // 2) Base58-encode those 34 bytes
        //    We'll implement a modified "Big Integer" base conversion
        //    by treating each byte as part of a base-256 number.

        // Allocate a temporary array for base58 digits (max length ~50 for 34 input bytes)
        uint8[] memory digits = new uint8[](70);
        digits[0] = 0;
        uint256 digitLength = 1;

        for (uint256 i = 0; i < input.length; i++) {
            uint256 carry = uint256(uint8(input[i]));
            for (uint256 j = 0; j < digitLength; j++) {
                carry += (uint256(digits[j]) << 8); // Base256 shift
                digits[j] = uint8(carry % 58);      // Remainder in base58
                carry /= 58;
            }

            // If carry is still > 0, push new digits
            while (carry > 0) {
                digits[digitLength] = uint8(carry % 58);
                digitLength++;
                carry /= 58;
            }
        }

        // 3) Handle leading zeros in the input → which become '1' in Base58
        //    Count how many 0x00 bytes at the front of 'input'
        uint256 leadingZeros = 0;
        for (uint256 i = 0; i < input.length; i++) {
            if (input[i] == 0) {
                leadingZeros++;
            } else {
                break;
            }
        }

        // 4) Finally, prepare the output string
        //    - leading zeros turn into '1'
        //    - then the actual base58 digits in reverse order
        uint256 outputSize = leadingZeros + digitLength;
        bytes memory result = new bytes(outputSize);

        // Fill in '1' for each leading zero
        for (uint256 i = 0; i < leadingZeros; i++) {
            result[i] = ALPHABET[0]; // '1'
        }

        // Base58 digits (reverse order)
        for (uint256 i = 0; i < digitLength; i++) {
            // digits[digitLength-1 - i] gives us the correct reversed order
            result[i + leadingZeros] = ALPHABET[digits[digitLength - 1 - i]];
        }

        return string(result);
    }
}