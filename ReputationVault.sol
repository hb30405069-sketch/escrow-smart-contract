// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title ReputationVault - A trust-backed freelance payment system
/// @author hb30405069-sketch
/// @notice Freelancers lock ETH as a reputation deposit. Clients rate their work. Rewards or penalties apply.

contract ReputationVault {
    struct Job {
        address freelancer;
        address client;
        uint256 deposit;
        uint256 deadline;
        bool submitted;
        bool rated;
        uint8 rating; // 1 to 5
    }

    uint256 public jobCounter;
    mapping(uint256 => Job) public jobs;
    mapping(address => uint256[]) public freelancerJobs;
    mapping(address => uint256[]) public clientJobs;
    mapping(address => uint256) public totalRatings;
    mapping(address => uint256) public ratingCount;

    event JobStarted(uint256 jobId, address indexed freelancer, address indexed client, uint256 deposit, uint256 deadline);
    event WorkSubmitted(uint256 jobId);
    event WorkRated(uint256 jobId, uint8 rating);
    event PaymentSettled(uint256 jobId, uint256 payout);

    modifier onlyClient(uint256 _jobId) {
        require(msg.sender == jobs[_jobId].client, "Not job client");
        _;
    }

    modifier onlyFreelancer(uint256 _jobId) {
        require(msg.sender == jobs[_jobId].freelancer, "Not job freelancer");
        _;
    }

    function startJob(address _client, uint256 _deadline) external payable {
        require(msg.value > 0, "Deposit required");
        require(_deadline > block.timestamp, "Invalid deadline");

        jobCounter++;
        jobs[jobCounter] = Job({
            freelancer: msg.sender,
            client: _client,
            deposit: msg.value,
            deadline: _deadline,
            submitted: false,
            rated: false,
            rating: 0
        });

        freelancerJobs[msg.sender].push(jobCounter);
        clientJobs[_client].push(jobCounter);

        emit JobStarted(jobCounter, msg.sender, _client, msg.value, _deadline);
    }

    function submitWork(uint256 _jobId) external onlyFreelancer(_jobId) {
        Job storage job = jobs[_jobId];
        require(!job.submitted, "Already submitted");
        job.submitted = true;

        emit WorkSubmitted(_jobId);
    }

    function rateWork(uint256 _jobId, uint8 _rating) external onlyClient(_jobId) {
        require(_rating >= 1 && _rating <= 5, "Invalid rating");
        Job storage job = jobs[_jobId];
        require(job.submitted, "Work not submitted");
        require(!job.rated, "Already rated");

        job.rated = true;
        job.rating = _rating;

        totalRatings[job.freelancer] += _rating;
        ratingCount[job.freelancer]++;

        emit WorkRated(_jobId, _rating);
    }

    function settle(uint256 _jobId) external {
        Job storage job = jobs[_jobId];
        require(job.rated, "Not rated yet");

        uint256 payout;
        if (job.rating >= 4) {
            payout = job.deposit + (job.deposit / 10); // 10% bonus
        } else if (job.rating == 3) {
            payout = job.deposit; // no bonus, no penalty
        } else {
            payout = job.deposit / 2; // 50% penalty
        }

        payable(job.freelancer).transfer(payout);
        emit PaymentSettled(_jobId, payout);

        delete jobs[_jobId]; // Clean up
    }

    function getReputation(address _freelancer) external view returns (uint256 avgRating) {
        if (ratingCount[_freelancer] == 0) return 0;
        return totalRatings[_freelancer] / ratingCount[_freelancer];
    }
}