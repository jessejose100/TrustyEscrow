

# `TrustyEscrow`

A decentralized escrow service for freelance work built on the Stacks blockchain. This Clarity smart contract provides a secure, trustless mechanism for clients to hold funds in escrow and for freelancers to receive payment upon successful completion of work. It automates the payment process, manages disputes, and ensures that funds are handled transparently and securely.

---

### **Key Features**

* **Secure Escrow:** Funds are held securely in the smart contract until both parties fulfill their obligations.

* **Decentralized:** The entire process---from creation to release of funds---is managed by the smart contract without the need for a central authority.

* **Transparent:** All transactions and state changes are recorded on the Stacks blockchain, providing a public and auditable history.

* **Automated Payments:** Upon client approval, the smart contract automatically releases the agreed-upon payment to the freelancer and deducts a service fee.

* **Dispute Resolution:** A built-in dispute mechanism allows the contract owner to mediate and resolve disagreements between parties, distributing funds according to a fair resolution.

---

### **Contract States and Functions**

The contract defines a clear workflow with several states for each escrow agreement.

#### **Escrow Statuses**

* `STATUS-CREATED` (u0): The escrow has been created by the client but is not yet funded.

* `STATUS-FUNDED` (u1): The client has deposited the agreed-upon amount into the contract.

* `STATUS-WORK-SUBMITTED` (u2): The freelancer has submitted their work for client review.

* `STATUS-COMPLETED` (u3): The client has approved the work, and funds have been distributed.

* `STATUS-DISPUTED` (u4): A dispute has been initiated by either the client or the freelancer.

* `STATUS-CANCELLED` (u5): (Not used in current implementation but reserved for future functionality).

#### **Public Functions**

* `create-escrow(freelancer, amount, deadline, work-description)`

    * Creates a new escrow agreement. The caller becomes the client.

    * **Parameters:**

        * `freelancer`: The principal address of the freelancer.

        * `amount`: The amount of STX to be held in escrow.

        * `deadline`: The block height by which the work must be submitted.

        * `work-description`: A brief description of the work to be completed.

    * **Returns:** `(ok uint)` with the new `escrow-id`.

* `fund-escrow(escrow-id)`

    * Transfers the STX amount specified in the escrow to the contract.

    * **Parameters:**

        * `escrow-id`: The ID of the escrow to fund.

    * **Returns:** `(ok true)`.

* `submit-work(escrow-id)`

    * Called by the freelancer to indicate that the work is complete.

    * **Parameters:**

        * `escrow-id`: The ID of the escrow.

    * **Returns:** `(ok true)`.

* `approve-and-release(escrow-id)`

    * Called by the client to approve the work and release funds. The contract automatically pays the freelancer and collects its fee.

    * **Parameters:**

        * `escrow-id`: The ID of the escrow.

    * **Returns:** `(ok true)`.

* `initiate-dispute(escrow-id, reason)`

    * Called by either the client or freelancer to initiate a dispute.

    * **Parameters:**

        * `escrow-id`: The ID of the escrow.

        * `reason`: A string explaining the reason for the dispute.

    * **Returns:** `(ok true)`.

* `resolve-dispute-with-distribution(escrow-id, resolution, client-percentage, freelancer-percentage, penalty-amount)`

    * **Restricted to the contract owner.** This function allows for a detailed resolution of a dispute.

    * **Parameters:**

        * `escrow-id`: The ID of the disputed escrow.

        * `resolution`: A description of the final resolution.

        * `client-percentage`: The percentage of the remaining funds to be returned to the client.

        * `freelancer-percentage`: The percentage of the remaining funds to be paid to the freelancer. The sum of `client-percentage` and `freelancer-percentage` must equal 100.

        * `penalty-amount`: An amount to be collected as a penalty in addition to the standard fee.

    * **Returns:** `(ok { ... })` with details of the distribution.

---

### **Private Functions**

These functions are internal helpers used by the public functions. They are not directly callable by users.

* `calculate-fee(amount)`

    * Calculates the standard 2.5% contract fee based on the escrow amount.

    * **Parameters:**

        * `amount`: The total escrow amount.

    * **Returns:** `uint`.

* `get-escrow-or-fail(escrow-id)`

    * A helper function to safely retrieve escrow data from the `escrows` map.

    * **Parameters:**

        * `escrow-id`: The ID of the escrow.

    * **Returns:** `(ok { ... })` or `ERR-NOT-FOUND`.

* `is-escrow-participant(escrow-id, caller)`

    * Checks if the calling principal is either the client or the freelancer for a given escrow.

    * **Parameters:**

        * `escrow-id`: The ID of the escrow.

        * `caller`: The principal to check.

    * **Returns:** `bool`.

---

### **Error Codes**

The contract uses standardized error codes to provide clear feedback.

* `u100`: `ERR-OWNER-ONLY` - Caller is not the contract owner.

* `u101`: `ERR-NOT-FOUND` - Escrow or dispute not found.

* `u102`: `ERR-UNAUTHORIZED` - Caller is not the client or freelancer.

* `u103`: `ERR-INVALID-STATUS` - The function was called in an incorrect escrow state.

* `u104`: `ERR-INSUFFICIENT-FUNDS` - Not enough funds (not used in current version).

* `u105`: `ERR-ALREADY-EXISTS` - Escrow ID already exists.

* `u106`: `ERR-INVALID-AMOUNT` - Invalid amount provided.

* `u107`: `ERR-EXPIRED` - The deadline for the work has passed.

---

### **Contract Ownership and Fees**

* **Contract Owner:** The contract owner (`CONTRACT-OWNER`) is the only one authorized to resolve disputes.

* **Fees:** A fee of `2.5%` is applied to each successful transaction. This fee is collected by the `CONTRACT-OWNER` upon the release of funds.

---

### **How to Use**

1\.  **Deploy the contract** on the Stacks blockchain.

2\.  **Client calls `create-escrow`** with the freelancer's address, amount, and deadline.

3\.  **Client calls `fund-escrow`** to transfer the STX into the contract.

4\.  **Freelancer calls `submit-work`** when the work is done.

5\.  **Client calls `approve-and-release`** to finalize the payment.

6\.  *In case of a problem,* either party can **call `initiate-dispute`**. The contract owner can then call `resolve-dispute-with-distribution` to settle the matter.

---

### **Contributing**

Contributions are welcome! Please feel free to open an issue or submit a pull request on the GitHub repository.

---

### **License**

This project is licensed under the MIT License.
